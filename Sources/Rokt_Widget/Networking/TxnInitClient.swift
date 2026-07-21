import Foundation

internal struct TxnInitClient {
    let baseURL: URL
    let accountId: String
    let sdkVersion: String
    let httpClient: HTTPClientAdapter
    let deviceHeaders: [String: String]

    init(
        baseURL: URL,
        accountId: String,
        sdkVersion: String,
        httpClient: HTTPClientAdapter = RoktHTTPClient(),
        deviceHeaders: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.httpClient = httpClient
        self.deviceHeaders = deviceHeaders
    }

    /// Fetches init config (headers only, no session in the response).
    func initSession(
        operating_system: String,
        layout_schema_version: String
    ) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("init")

        // Device/app context headers (incl. rokt-package-name / rokt-package-version)
        // ride in via NetworkingHelper.txnDeviceHeaders, matching offers/events. The
        // explicit init headers below take precedence for any shared key.
        var headers: RoktHTTPHeaders = deviceHeaders
        headers["rokt-account-id"] = accountId
        headers["rokt-os-type"] = operating_system
        headers["rokt-sdk-version"] = sdkVersion
        headers["rokt-layout-schema-version"] = layout_schema_version
        headers["x-request-id"] = UUID().uuidString

        return try await withCheckedThrowingContinuation { continuation in
            httpClient.startRequestWith(
                urlAddress: url.absoluteString,
                method: .get,
                parameters: nil,
                parameterArray: nil,
                headers: headers,
                onRequestStart: nil,
                requestTimeout: nil,
                completionQueue: .main,
                completionHandler: { result in
                    if let error = result.responseError {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (result.responseData, result.httpURLResponse))
                    }
                }
            )
        }
    }
}
