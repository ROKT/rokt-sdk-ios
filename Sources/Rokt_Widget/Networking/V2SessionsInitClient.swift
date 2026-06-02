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

    func initSession(
        operating_system: String,
        sdk_version: String,
        layout_schema_version: String
    ) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("init")

        let requestBody = V2SessionsInitRequest(
            operatingSystem: operating_system,
            sdkVersion: sdk_version,
            layoutSchemaVersion: layout_schema_version
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw V2SessionsInitClientError.bodyEncodingFailed
        }

        let headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "Authorization": authToken,
            "rokt-platform-type": "iOS",
            "rokt-integration-type": "msdk-ios",
            "x-request-id": UUID().uuidString,
            "Content-Type": "application/json"
        ]

        return try await withCheckedThrowingContinuation { continuation in
            httpClient.startRequestWith(
                urlAddress: url.absoluteString,
                method: .post,
                parameters: bodyParameters,
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

internal enum V2SessionsInitClientError: Error {
    case bodyEncodingFailed
}

internal struct V2SessionsInitRequest: Encodable {
    let operatingSystem: String
    let sdkVersion: String
    let layoutSchemaVersion: String

    enum CodingKeys: String, CodingKey {
        case operatingSystem = "operating_system"
        case sdkVersion = "sdk_version"
        case layoutSchemaVersion = "layout_schema_version"
    }
}
