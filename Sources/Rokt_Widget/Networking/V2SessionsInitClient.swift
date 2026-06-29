// periphery:ignore:all - referenced from Tests/ContractTests/V2SessionsInitClientPactSpec.swift

import Foundation

internal struct V2SessionsInitClient {
    let baseURL: URL
    let accountId: String
    let authToken: String
    let sdkVersion: String
    let httpClient: HTTPClientAdapter

    init(
        baseURL: URL,
        accountId: String,
        authToken: String,
        sdkVersion: String,
        httpClient: HTTPClientAdapter = RoktHTTPClient()
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.authToken = authToken
        self.sdkVersion = sdkVersion
        self.httpClient = httpClient
    }

    /// Calls `GET /v2/sessions/init`.
    ///
    /// All inputs travel as request headers — there is no body — so the request
    /// is a plain, cacheable GET. Operating system, layout schema version and
    /// SDK version are carried as `rokt-os-type`, `rokt-layout-schema-version`
    /// and `rokt-sdk-version` respectively.
    func initSession(
        operating_system: String,
        sdk_version: String,
        layout_schema_version: String
    ) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("init")

        let headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "rokt-os-type": operating_system,
            "rokt-layout-schema-version": layout_schema_version,
            "rokt-sdk-version": sdk_version,
            "Authorization": authToken,
            "rokt-platform-type": "iOS",
            "rokt-integration-type": "msdk-ios",
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
