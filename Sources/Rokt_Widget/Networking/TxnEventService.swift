import Foundation

internal struct TxnEventService {
    // Cap events per request so large backlogs are split across batches.
    static let maxEventsPerBatch = 25

    static let unauthorizedDiagnosticCode = "[TXN_EVENTS_401]"

    enum TxnEventError: Error, Equatable {
        case invalidBaseURL
        case unexpectedStatusCode(Int)
    }

    let sessionManager: TxnSessionManager
    let maxRetries: Int
    let baseBackoff: TimeInterval
    let sleep: (TimeInterval) async throws -> Void

    private let client: TxnEventsClient?

    init(
        environment: Environment,
        accountId: String,
        sdkVersion: String,
        sessionManager: TxnSessionManager,
        httpClient: HTTPClientAdapter = RoktHTTPClient(),
        deviceHeaders: [String: String] = [:],
        maxRetries: Int = 3,
        requestTimeout: TimeInterval = 7,
        baseBackoff: TimeInterval = 1.0,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.sessionManager = sessionManager
        self.maxRetries = maxRetries
        self.baseBackoff = baseBackoff
        self.sleep = sleep

        if let baseURL = URL(string: environment.gatewayBaseURL) {
            httpClient.updateTimeout(timeout: requestTimeout)
            self.client = TxnEventsClient(
                baseURL: baseURL,
                accountId: accountId,
                sdkVersion: sdkVersion,
                deviceHeaders: deviceHeaders,
                httpClient: httpClient
            )
        } else {
            self.client = nil
        }
    }

    func send(events: [TxnEvent]) async throws {
        guard !events.isEmpty else { return }
        guard client != nil else { throw TxnEventError.invalidBaseURL }

        // Send batches sequentially (awaiting each) to preserve event order and so a
        // session token refreshed by one batch is picked up by the next.
        for start in stride(from: 0, to: events.count, by: Self.maxEventsPerBatch) {
            let end = min(start + Self.maxEventsPerBatch, events.count)
            try await sendBatch(events: Array(events[start..<end]))
        }
    }

    private func sendBatch(events: [TxnEvent]) async throws {
        guard let client else { throw TxnEventError.invalidBaseURL }

        let authToken = await sessionManager.authorizationHeader

        var attempt = 0
        while true {
            do {
                let (data, response) = try await client.recordEvents(events: events, authToken: authToken)
                let statusCode = response?.statusCode ?? 0

                if isRetryable(statusCode: statusCode), attempt < maxRetries {
                    // A rate-limited/overloaded gateway (429/503) can pace us via `Retry-After`;
                    // honor it when present, otherwise fall back to exponential backoff.
                    try await sleep(retryAfterDelay(from: response) ?? backoffDelay(attempt: attempt))
                    attempt += 1
                    continue
                }

                // A 401 here means a forged/corrupted token (invalid_signature, invalid_issuer,
                // etc.) — the recoverable `expired`/`unknown_kid` cases return 200 with a fresh
                // token bound to the same session id, handled by the success path below. These 401s
                // are exceptional and not recoverable (re-minting would attach the events to a new,
                // unlinked session), so drop the batch, clear the bad session, and diagnose.
                if statusCode == HTTPStatusCode.unauthorized.rawValue {
                    RoktLogger.shared.error("Events returned 401; dropping session and \(events.count) event(s)")
                    RoktAPIHelper.sendDiagnostics(
                        message: Self.unauthorizedDiagnosticCode,
                        callStack: "Dropped \(events.count) event(s) after events 401"
                    )
                    await sessionManager.clear()
                    throw TxnEventError.unexpectedStatusCode(statusCode)
                }

                guard (200..<300).contains(statusCode) else {
                    throw TxnEventError.unexpectedStatusCode(statusCode)
                }

                if let data,
                   let decoded = try? JSONDecoder().decode(TxnEventsResponse.self, from: data),
                   let sessionToken = decoded.sessionToken {
                    await sessionManager.update(sessionToken: sessionToken)
                }
                return
            } catch let error where isRetryable(error: error) && attempt < maxRetries {
                try await sleep(backoffDelay(attempt: attempt))
                attempt += 1
                continue
            }
        }
    }

    // 408 (request timeout) and 429 (too many requests) are transient and safe to replay,
    // matching the web + Android recoverable-code set.
    private func isRetryable(statusCode: Int) -> Bool {
        [408, 429, 500, 502, 503, 504].contains(statusCode)
    }

    // Reads the `Retry-After` header in delta-seconds form (fractional allowed, mirroring web).
    // The HTTP-date form is not honored; callers fall back to exponential backoff.
    private func retryAfterDelay(from response: HTTPURLResponse?) -> TimeInterval? {
        guard let raw = response?.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces),
              let seconds = Double(raw), seconds >= 0
        else { return nil }
        return seconds
    }

    // Transient transport failures only; a hard-offline device fails fast.
    private func isRetryable(error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed:
            return true
        default:
            return false
        }
    }

    // Exponential backoff with jitter to avoid hammering a struggling gateway. The `1000·4^n`
    // curve and ≤25% jitter mirror web (`BASE_DELAY_MS * 4^(retryCount-1)` + `random·0.25`);
    // `attempt` is 0-based here, so the first retry waits `baseBackoff` (1s).
    private func backoffDelay(attempt: Int) -> TimeInterval {
        let base = baseBackoff * pow(4, Double(attempt))
        return base + Double.random(in: 0...(base * 0.25))
    }
}
