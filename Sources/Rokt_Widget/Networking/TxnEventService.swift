import Foundation

internal struct TxnEventService {
    // Cap events per request so large backlogs are split across batches.
    static let maxEventsPerBatch = 25

    static let unauthorizedDiagnosticCode = "[TXN_EVENTS_401]"

    // Longest `Retry-After` honored; the batch stays in memory for the whole pause.
    static let maxRetryAfterDelay: TimeInterval = 60

    enum TxnEventError: Error, Equatable {
        case invalidBaseURL
        case unexpectedStatusCode(Int)
    }

    /// How a batch is bound to a session. Each batch resolves its route on its own, from one read
    /// of the session manager, just before it is sent.
    private enum Route {
        /// Follows the live session: the stored bearer when there is one, otherwise neither a
        /// bearer nor a stamp, and the server mints a fresh session.
        case live
        /// Bound to the session that produced the batch: that session's bearer while it is still
        /// the stored session with an unexpired token, otherwise stamped with its id.
        case origin(String)
        /// Always stamped with the session id, never a bearer.
        case replay(String)
    }

    let sessionManager: TxnSessionManager
    let maxRetries: Int
    let baseBackoff: TimeInterval
    let sleep: (TimeInterval) async throws -> Void

    private let client: TxnEventsClient?
    private let pendingStore: TxnPendingEventStoring?

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
        pendingStore: TxnPendingEventStoring? = nil,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: NetworkRetryRules.sleepNanoseconds(clamping: seconds))
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

    /// Sends events for the current session, authenticated with the stored token.
    func send(events: [TxnEvent]) async throws {
        try await send(events: events, route: .live)
    }

    /// Sends events bound to the session that produced them. Each batch goes out with that
    /// session's bearer while it is still the stored session and its token is unexpired; otherwise
    /// it goes out stamped with `originSessionId` and without Authorization, like a replay, so it
    /// can neither ride a later session's token nor start a session of its own.
    func send(events: [TxnEvent], originSessionId: String) async throws {
        try await send(events: events, route: .origin(originSessionId))
    }

    /// Replays a batch that outlived the session it belongs to, unauthenticated with `session_id`
    /// stamped on every event, so it stays on that session rather than the current one.
    func replay(events: [TxnEvent], sessionId: String) async throws {
        try await send(events: events, route: .replay(sessionId))
    }

    private func send(events: [TxnEvent], route: Route) async throws {
        guard !events.isEmpty else { return }
        guard client != nil else { throw TxnEventError.invalidBaseURL }

        // Send batches sequentially (awaiting each) to preserve event order and so a session token
        // refreshed by one batch is picked up by the next. Each batch resolves its route afresh, so
        // a token that expires between batches flips the later ones to the stamped form.
        for start in stride(from: 0, to: events.count, by: Self.maxEventsPerBatch) {
            let end = min(start + Self.maxEventsPerBatch, events.count)
            let batch = Array(events[start..<end])
            do {
                try await sendBatch(events: batch, route: route)
            } catch {
                // Persist recoverable failures (exhausted 5xx/transport) for replay on the next
                // init instead of dropping them; permanent failures (400/401) are not replayed.
                if shouldPersistOnFailure(error) {
                    // Re-bind to the originating session so a repeated failure stays attributable.
                    let sessionId = await boundSessionId(for: route)
                    pendingStore?.persist(events: batch, sessionId: sessionId)
                }
                throw error
            }
        }
    }

    // The session a failed batch is persisted against: the one it is bound to when known, otherwise
    // whichever session is live now.
    private func boundSessionId(for route: Route) async -> String? {
        switch route {
        case .live:
            return await sessionManager.currentSessionId
        case .origin(let sessionId), .replay(let sessionId):
            return sessionId
        }
    }

    // The bearer and the `session_id` stamp for one batch, never both. `.live` reads the stored
    // bearer, nil when there is no unexpired token; `.replay` always stamps; `.origin` asks for that
    // session's bearer in one actor call, so the id and the expiry cannot disagree, and stamps when
    // none comes back because the session is no longer the stored one or its token has expired.
    private func resolve(_ route: Route) async -> (authToken: String?, stampedSessionId: String?) {
        switch route {
        case .live:
            let authToken = await sessionManager.authorizationHeader
            return (authToken, nil)
        case .replay(let sessionId):
            return (nil, sessionId)
        case .origin(let sessionId):
            if let authToken = await sessionManager.authorizationHeader(forSession: sessionId) {
                return (authToken, nil)
            }
            return (nil, sessionId)
        }
    }

    // A recoverable failure that exhausted retries (or a transient transport error) is worth
    // replaying; a 400/401 is permanent and must not be re-sent.
    private func shouldPersistOnFailure(_ error: Error) -> Bool {
        if let txnError = error as? TxnEventError, case .unexpectedStatusCode(let code) = txnError {
            return isRetryable(statusCode: code)
        }
        return isRetryable(error: error)
    }

    private func sendBatch(events: [TxnEvent], route: Route) async throws {
        guard let client else { throw TxnEventError.invalidBaseURL }

        let (authToken, stampedSessionId) = await resolve(route)
        let payload: [TxnEvent]
        if let stampedSessionId {
            // No Authorization on a stamped batch (`resolve` never returns both): a token
            // disagreeing with the stamped session_id is rejected as a conflict.
            payload = events.map { event in
                var stamped = event
                stamped.sessionId = stampedSessionId
                return stamped
            }
        } else {
            payload = events
        }

        var attempt = 0
        while true {
            do {
                let (data, response) = try await client.recordEvents(events: payload, authToken: authToken)
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
                    // A stamped batch carries no token, so its 401 says nothing about the live
                    // session.
                    if stampedSessionId == nil {
                        await sessionManager.clear()
                    }
                    throw TxnEventError.unexpectedStatusCode(statusCode)
                }

                guard (200..<300).contains(statusCode) else {
                    throw TxnEventError.unexpectedStatusCode(statusCode)
                }

                // A stamped batch's response describes the stamped session, which by now may not be
                // the stored one; adopting its token would overwrite the live one.
                if stampedSessionId == nil,
                   let data,
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
    // The HTTP-date form is not honored; callers fall back to exponential backoff. `Double.init`
    // also parses "inf"/"nan", which are treated the same way, and anything above
    // `maxRetryAfterDelay` is clamped rather than rejected so a rate-limiting gateway is still paced.
    private func retryAfterDelay(from response: HTTPURLResponse?) -> TimeInterval? {
        guard let raw = response?.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces),
              let seconds = Double(raw), seconds.isFinite, seconds >= 0
        else { return nil }
        return min(seconds, Self.maxRetryAfterDelay)
    }

    // Transient transport failures worth retrying, including a device that is offline:
    // batches are persisted and replayed, so an offline send is worth coming back for.
    private func isRetryable(error: Error) -> Bool {
        NetworkRetryRules.isTransientTransportFailure(error, policy: .transientIncludingOffline)
    }

    // Exponential backoff with jitter to avoid hammering a struggling gateway.
    private func backoffDelay(attempt: Int) -> TimeInterval {
        let base = baseBackoff * pow(2, Double(attempt))
        return base + Double.random(in: 0...(base/2))
    }
}
