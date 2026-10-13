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

    let environment: Environment
    let accountId: String
    let sdkVersion: String
    let layoutSchemaVersion: String
    let httpClient: HTTPClientAdapter
    let deviceHeaders: [String: String]
    let requestTimeout: TimeInterval

    init(
        environment: Environment,
        accountId: String,
        sdkVersion: String,
        layoutSchemaVersion: String,
        httpClient: HTTPClientAdapter = RoktHTTPClient(),
        deviceHeaders: [String: String] = [:],
        requestTimeout: TimeInterval = 10
    ) {
        self.environment = environment
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.layoutSchemaVersion = layoutSchemaVersion
        self.httpClient = httpClient
        self.deviceHeaders = deviceHeaders
        self.requestTimeout = requestTimeout
    }

    func initSession() async throws -> InitResult {
        guard let baseURL = URL(string: environment.gatewayBaseURL) else {
            throw TxnInitError.invalidBaseURL
        }

        httpClient.updateTimeout(timeout: requestTimeout)

        let client = TxnInitClient(
            baseURL: baseURL,
            accountId: accountId,
            sdkVersion: sdkVersion,
            httpClient: httpClient,
            deviceHeaders: deviceHeaders
        )

        // One request. Trying again, with growing waits, is the init scheduler's job.
        let (data, response) = try await client.initSession(
            operating_system: "ios",
            layout_schema_version: layoutSchemaVersion
        )
        let statusCode = response?.statusCode ?? 0

        guard (200..<300).contains(statusCode) else {
            throw TxnInitError.unexpectedStatusCode(statusCode)
        }
        guard let data else {
            throw TxnInitError.missingResponseData
        }

        let decoded = try JSONDecoder().decode(TxnInitResponse.self, from: data)
        return InitResult(response: decoded, featureFlags: decoded.featureFlags.toInitFeatureFlags())
    }
}
