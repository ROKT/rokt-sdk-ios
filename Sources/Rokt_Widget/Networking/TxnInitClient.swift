import Foundation

internal struct TxnInitClient {
    let baseURL: URL
    let accountId: String
    let sdkVersion: String
    let httpClient: HTTPClientAdapter

    init(
        baseURL: URL,
        accountId: String,
        sdkVersion: String,
        httpClient: HTTPClientAdapter = RoktHTTPClient()
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.httpClient = httpClient
    }

    /// Fetches init config (headers only, no session in the response).
    func initSession(
        operating_system: String,
        layout_schema_version: String
    ) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("init")

        let headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "rokt-os-type": operating_system,
            "rokt-sdk-version": sdkVersion,
            "rokt-layout-schema-version": layout_schema_version,
            "x-request-id": UUID().uuidString
        ]

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
