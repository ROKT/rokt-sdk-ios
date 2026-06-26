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
    let deviceHeaders: [String: String]
    let maxRetries: Int
    let requestTimeout: TimeInterval
    let baseBackoff: TimeInterval
    let sleep: (TimeInterval) async throws -> Void
    let makeRequestId: () -> String
    let makePageInstanceGuid: () -> String
    let completionQueue: DispatchQueue

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
        },
        makeRequestId: @escaping () -> String = { UUID().uuidString },
        makePageInstanceGuid: @escaping () -> String = { UUID().uuidString },
        completionQueue: DispatchQueue = .main
    ) {
        self.environment = environment
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.sessionManager = sessionManager
        self.httpClient = httpClient
        self.deviceHeaders = deviceHeaders
        self.maxRetries = maxRetries
        self.requestTimeout = requestTimeout
        self.baseBackoff = baseBackoff
        self.sleep = sleep
        self.makeRequestId = makeRequestId
        self.makePageInstanceGuid = makePageInstanceGuid
        self.completionQueue = completionQueue
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
        let privacyControl = buildPrivacyControl(from: attributes)
        let sanitisedAttributes = RoktAPIHelper.removePrivacyControlAttributes(attributes: attributes)
        let enrichedAttributes = AttributeEnrichment.shared.enrich(attributes: sanitisedAttributes, config: config)

        Task {
            do {
                let experience = try await fetchExperienceString(
                    pageIdentifier: viewName ?? "",
                    attributes: enrichedAttributes,
                    privacyControl: privacyControl
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
        privacyControl: SelectPrivacyControl?
    ) async throws -> String {
        guard let baseURL = URL(string: environment.gatewayBaseURL) else {
            throw OffersError.invalidBaseURL
        }

        httpClient.updateTimeout(timeout: requestTimeout)

        let client = OffersClient(
            baseURL: baseURL,
            accountId: accountId,
            authToken: await sessionManager.authorizationHeader,
            sdkVersion: sdkVersion,
            pageInstanceGuid: makePageInstanceGuid(),
            deviceHeaders: deviceHeaders,
            httpClient: httpClient
        )
        let input = OffersInput(
            requestId: makeRequestId(),
            pageIdentifier: pageIdentifier,
            attributes: attributes,
            privacyControl: privacyControl
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
                return try SelectExperienceAdapter.experienceJSONString(from: decoded)
            } catch let error where isRetryable(error: error) && attempt < maxRetries {
                try await sleep(backoffDelay(attempt: attempt))
                attempt += 1
                continue
            }
        }
    }

    private func buildPrivacyControl(from attributes: [String: String]) -> SelectPrivacyControl? {
        let payload = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)
        guard !payload.isEmpty else { return nil }
        return SelectPrivacyControl(
            noFunctional: payload[RoktAPIHelper.noFunctionalKey],
            noTargeting: payload[RoktAPIHelper.noTargetingKey],
            doNotShareOrSell: payload[RoktAPIHelper.doNotShareOrSellKey]
        )
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
