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
    // Holds events that 401'd so they are re-sent under the next minted session rather than dropped.
    let pendingStore: TxnPendingEventsStore

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
        pendingStore: TxnPendingEventsStore = .shared,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.sessionManager = sessionManager
        self.maxRetries = maxRetries
        self.baseBackoff = baseBackoff
        self.pendingStore = pendingStore
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
        guard client != nil else { throw TxnEventError.invalidBaseURL }

        // Re-send anything buffered from a prior 401 first (order preserved) — by now an offers
        // call has typically minted a fresh session, so these transfer to it instead of being
        // dropped. `pending.count` marks the boundary so a later non-session failure only
        // re-buffers the still-undelivered buffered events, not the current batch.
        let pending = await pendingStore.drain()
        let all = pending + events
        guard !all.isEmpty else { return }

        // Send batches sequentially (awaiting each) to preserve event order and so a
        // session token refreshed by one batch is picked up by the next.
        var start = 0
        while start < all.count {
            let end = min(start + Self.maxEventsPerBatch, all.count)
            do {
                try await sendBatch(events: Array(all[start..<end]))
                start = end
            } catch let error as TxnEventError where error == .unexpectedStatusCode(HTTPStatusCode.unauthorized.rawValue) {
                // Session rejected: buffer this batch and everything after it so the events are
                // re-sent under the next minted session instead of dropped. Best-effort: the
                // session was already cleared in sendBatch, so we don't propagate.
                let undelivered = Array(all[start...])
                RoktLogger.shared.error(
                    "Events returned 401; dropped session and buffered \(undelivered.count) event(s) to re-send " +
                    "under the next minted session (tx-api auth handling may have changed if this persists)"
                )
                await pendingStore.add(undelivered)
                return
            } catch {
                // Non-session failure: don't lose events that were buffered from a prior 401
                // (they predate this call); let current-batch failures surface as before.
                if start < pending.count {
                    await pendingStore.add(Array(all[start..<pending.count]))
                }
                throw error
            }
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

                // Token rejected: drop the stale session so the next offers call re-mints a fresh
                // one, then surface 401 so `send` can buffer the batch for re-send under that new
                // session (events are best-effort, so the batch itself is not retried here).
                if statusCode == HTTPStatusCode.unauthorized.rawValue {
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
