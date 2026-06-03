// periphery:ignore:all - net-new v2 init coordinator, not yet wired into the live path
import Foundation

internal struct TxnInitService {
    enum TxnInitError: Error, Equatable {
        case invalidBaseURL
        case missingResponseData
        case unexpectedStatusCode(Int)
    }

    struct InitResult {
        let response: TxnInitResponse
        let featureFlags: InitFeatureFlags
    }

    let environment: TxnEnvironment
    let accountId: String
    let sdkVersion: String
    let layoutSchemaVersion: String
    let sessionManager: TxnSessionManager
    let httpClient: HTTPClientAdapter
    let maxRetries: Int
    let requestTimeout: TimeInterval
    let baseBackoff: TimeInterval
    let sleep: (TimeInterval) async throws -> Void

    init(
        environment: TxnEnvironment,
        accountId: String,
        sdkVersion: String,
        layoutSchemaVersion: String,
        sessionManager: TxnSessionManager,
        httpClient: HTTPClientAdapter = RoktHTTPClient(),
        maxRetries: Int = 3,
        requestTimeout: TimeInterval = 7,
        baseBackoff: TimeInterval = 0.2,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.environment = environment
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.layoutSchemaVersion = layoutSchemaVersion
        self.sessionManager = sessionManager
        self.httpClient = httpClient
        self.maxRetries = maxRetries
        self.requestTimeout = requestTimeout
        self.baseBackoff = baseBackoff
        self.sleep = sleep
    }

    func initSession() async throws -> InitResult {
        guard let baseURL = URL(string: environment.gatewayBaseURL) else {
            throw TxnInitError.invalidBaseURL
        }

        httpClient.updateTimeout(timeout: requestTimeout)

        let client = V2SessionsInitClient(
            baseURL: baseURL,
            accountId: accountId,
            authToken: sessionManager.authorizationHeader,
            sdkVersion: sdkVersion,
            httpClient: httpClient
        )

        var attempt = 0
        while true {
            do {
                let (data, response) = try await client.initSession(
                    operating_system: "ios",
                    sdk_version: sdkVersion,
                    layout_schema_version: layoutSchemaVersion
                )
                let statusCode = response?.statusCode ?? 0

                if isRetryable(statusCode: statusCode), attempt < maxRetries {
                    try await sleep(backoffDelay(attempt: attempt))
                    attempt += 1
                    continue
                }

                guard (200..<300).contains(statusCode) else {
                    throw TxnInitError.unexpectedStatusCode(statusCode)
                }
                guard let data else {
                    throw TxnInitError.missingResponseData
                }

                let decoded = try JSONDecoder().decode(TxnInitResponse.self, from: data)
                sessionManager.update(sessionId: decoded.sessionId, sessionToken: decoded.sessionToken)
                return InitResult(response: decoded, featureFlags: decoded.featureFlags.toInitFeatureFlags())
            } catch let error where isRetryable(error: error) && attempt < maxRetries {
                try await sleep(backoffDelay(attempt: attempt))
                attempt += 1
                continue
            }
        }
    }

    private func isRetryable(statusCode: Int) -> Bool {
        [500, 502, 503].contains(statusCode)
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
