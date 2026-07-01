import Foundation

/// Fetches an offers experience from `POST /v2/sessions/offers`, rolls the session
/// token forward, and adapts the response into the experience string the renderer
/// consumes. Mirrors ``TxnInitService``'s retry/backoff and reports back through the
/// same `successLayout`/`failure` callbacks the offers call site already uses.
internal struct OffersService {
    enum OffersError: Error, Equatable {
        case invalidBaseURL
        case missingResponseData
        case unexpectedStatusCode(Int)
    }

    let environment: Environment
    let accountId: String
    let sdkVersion: String
    let sessionManager: TxnSessionManager
    let httpClient: HTTPClientAdapter
    let attributeEnrichment: AttributeEnrichment
    let deviceHeaders: [String: String]
    let maxRetries: Int
    let requestTimeout: TimeInterval
    let baseBackoff: TimeInterval
    let sleep: (TimeInterval) async throws -> Void
    let makeRequestId: () -> String
    let makePageInstanceGuid: () -> String
    let completionQueue: DispatchQueue
    // Real-time event store seams (injected for tests). `captureEvents` stores the response's
    // events for the next call; it only adds (no global clear) to mirror the v1 capture and
    // avoid wiping triggered events the events/v1 paths share in RealTimeEventManager.shared.
    let triggeredEvents: () -> [TriggeredRealTimeEvent]
    let captureEvents: ([UntriggeredRealTimeEvent]) -> Void

    init(
        environment: Environment,
        accountId: String,
        sdkVersion: String,
        sessionManager: TxnSessionManager,
        httpClient: HTTPClientAdapter = RoktHTTPClient(),
        attributeEnrichment: AttributeEnrichment = .shared,
        deviceHeaders: [String: String] = [:],
        maxRetries: Int = 3,
        requestTimeout: TimeInterval = 7,
        baseBackoff: TimeInterval = 0.2,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        makeRequestId: @escaping () -> String = { UUID().uuidString },
        makePageInstanceGuid: @escaping () -> String = { UUID().uuidString },
        completionQueue: DispatchQueue = .main,
        triggeredEvents: @escaping () -> [TriggeredRealTimeEvent] = {
            RealTimeEventManager.shared.getTriggeredEvents()
        },
        captureEvents: @escaping ([UntriggeredRealTimeEvent]) -> Void = { events in
            RealTimeEventManager.shared.addUntriggeredEvents(events)
        }
    ) {
        self.environment = environment
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.sessionManager = sessionManager
        self.httpClient = httpClient
        self.attributeEnrichment = attributeEnrichment
        self.deviceHeaders = deviceHeaders
        self.maxRetries = maxRetries
        self.requestTimeout = requestTimeout
        self.baseBackoff = baseBackoff
        self.sleep = sleep
        self.makeRequestId = makeRequestId
        self.makePageInstanceGuid = makePageInstanceGuid
        self.completionQueue = completionQueue
        self.triggeredEvents = triggeredEvents
        self.captureEvents = captureEvents
    }

    /// Builds the request from the partner inputs, fetches the experience, and reports
    /// the experience string (or failure) on ``completionQueue``.
    func getExperienceData(
        viewName: String?,
        attributes: [String: String],
        config: RoktConfig?,
        onRequestStart: (() -> Void)? = nil,
        successLayout: ((String?) -> Void)? = nil,
        failure: ((Error, Int?, String) -> Void)? = nil
    ) {
        onRequestStart?()

        // Extract privacy KVPs before sanitising, then enrich the remaining attributes.
        // gpc_enabled travels under `privacy`, separate from `privacy_control`, to match Android.
        let privacyPayload = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)
        let privacyControl = buildPrivacyControl(from: privacyPayload)
        let privacy = buildPrivacy(from: privacyPayload)
        let sanitisedAttributes = RoktAPIHelper.removePrivacyControlAttributes(attributes: attributes)
        let enrichedAttributes = attributeEnrichment.enrich(attributes: sanitisedAttributes, config: config)

        Task {
            do {
                let experience = try await fetchExperienceString(
                    pageIdentifier: viewName ?? "",
                    attributes: enrichedAttributes,
                    privacyControl: privacyControl,
                    privacy: privacy
                )
                completionQueue.async { successLayout?(experience) }
            } catch {
                let statusCode = Self.statusCode(from: error)
                completionQueue.async { failure?(error, statusCode, "") }
            }
        }
    }

    private func fetchExperienceString(
        pageIdentifier: String,
        attributes: [String: String],
        privacyControl: SelectPrivacyControl?,
        privacy: SelectPrivacy?
    ) async throws -> String {
        guard let baseURL = URL(string: environment.gatewayBaseURL) else {
            throw OffersError.invalidBaseURL
        }

        httpClient.updateTimeout(timeout: requestTimeout)

        let authToken = await sessionManager.authorizationHeader
        let client = OffersClient(
            baseURL: baseURL,
            accountId: accountId,
            authToken: authToken,
            sdkVersion: sdkVersion,
            pageInstanceGuid: makePageInstanceGuid(),
            deviceHeaders: deviceHeaders,
            httpClient: httpClient
        )
        // Forward events triggered during the previous placement; read once, before retries,
        // and only with a live session to attribute them to (matching Android). As on the v1
        // path, triggered events are not cleared after forwarding — they ride subsequent
        // requests until session invalidation; re-send is expected (the "only adds, no clear"
        // note elsewhere is about the untriggered response-capture, not this read).
        let forwardedEvents = authToken != nil ? SelectEventMapper.requestEvents(from: triggeredEvents()) : []
        let input = OffersInput(
            requestId: makeRequestId(),
            pageIdentifier: pageIdentifier,
            attributes: attributes,
            privacyControl: privacyControl,
            privacy: privacy,
            events: forwardedEvents.isEmpty ? nil : forwardedEvents
        )

        var attempt = 0
        while true {
            do {
                let (data, response) = try await client.fetchOffers(input: input)
                let statusCode = response?.statusCode ?? 0

                if isRetryable(statusCode: statusCode), attempt < maxRetries {
                    try await sleep(backoffDelay(attempt: attempt))
                    attempt += 1
                    continue
                }

                guard (200..<300).contains(statusCode) else {
                    throw OffersError.unexpectedStatusCode(statusCode)
                }
                guard let data else {
                    throw OffersError.missingResponseData
                }

                let decoded = try JSONDecoder().decode(SelectResponse.self, from: data)
                // Roll the refreshed token forward for the next offers/events call.
                await sessionManager.update(sessionToken: decoded.sessionToken)
                // Capture the echoed events so the next placement can forward them back.
                if let eventData = decoded.eventData {
                    captureEvents(SelectEventMapper.untriggeredEvents(from: eventData))
                }
                return try SelectExperienceAdapter.experienceJSONString(from: decoded)
            } catch let error where isRetryable(error: error) && attempt < maxRetries {
                try await sleep(backoffDelay(attempt: attempt))
                attempt += 1
                continue
            }
        }
    }

    // Both builders read the same parsed payload; getExperienceData computes it once.
    private func buildPrivacyControl(from payload: [String: Bool]) -> SelectPrivacyControl? {
        guard payload[RoktAPIHelper.noFunctionalKey] != nil
            || payload[RoktAPIHelper.noTargetingKey] != nil
            || payload[RoktAPIHelper.doNotShareOrSellKey] != nil else { return nil }
        return SelectPrivacyControl(
            noFunctional: payload[RoktAPIHelper.noFunctionalKey],
            noTargeting: payload[RoktAPIHelper.noTargetingKey],
            doNotShareOrSell: payload[RoktAPIHelper.doNotShareOrSellKey]
        )
    }

    // gpc_enabled is a sibling of privacy_control (Android parity), omitted when the partner sent none.
    private func buildPrivacy(from payload: [String: Bool]) -> SelectPrivacy? {
        guard let gpcEnabled = payload[RoktAPIHelper.gpcEnabledKey] else { return nil }
        return SelectPrivacy(gpcEnabled: gpcEnabled)
    }

    static func statusCode(from error: Error) -> Int? {
        if case OffersError.unexpectedStatusCode(let code) = error {
            return code
        }
        return nil
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
