import Foundation

internal struct TxnEventService {
    // Cap events per POST /v2/sessions/events so a large backlog is split across
    // several requests instead of one oversized payload.
    static let maxEventsPerBatch = 25

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
        baseBackoff: TimeInterval = 0.2,
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
                    try await sleep(backoffDelay(attempt: attempt))
                    attempt += 1
                    continue
                }

                // Token rejected: drop the stale session so the next offers call re-mints a
                // fresh one. Events are best-effort, so we don't retry the batch.
                if statusCode == HTTPStatusCode.unauthorized.rawValue {
                    RoktLogger.shared.verbose("Events returned 401; dropping session")
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

    private func isRetryable(statusCode: Int) -> Bool {
        [500, 502, 503, 504].contains(statusCode)
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

    // Exponential backoff with jitter to avoid hammering a struggling gateway.
    private func backoffDelay(attempt: Int) -> TimeInterval {
        let base = baseBackoff * pow(2, Double(attempt))
        return base + Double.random(in: 0...(base/2))
    }
}
