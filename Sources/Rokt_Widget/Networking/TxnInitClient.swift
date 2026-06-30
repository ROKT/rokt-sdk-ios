import Foundation

internal struct TxnInitClient {
    let baseURL: URL
    let accountId: String
    let authToken: String?
    let sdkVersion: String
    let httpClient: HTTPClientAdapter

    init(
        baseURL: URL,
        accountId: String,
        authToken: String? = nil,
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
        layout_schema_version: String
    ) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("config")

        let requestBody = TxnInitRequest(
            operatingSystem: operating_system,
            sdkVersion: sdkVersion,
            layoutSchemaVersion: layout_schema_version
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw TxnInitClientError.bodyEncodingFailed
        }

        var headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "x-request-id": UUID().uuidString,
            "Content-Type": "application/json"
        ]
        // Authorization is optional: with no stored token the server mints a fresh session.
        if let authToken, !authToken.isEmpty {
            headers["Authorization"] = authToken
        }

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

internal enum TxnInitClientError: Error {
    case bodyEncodingFailed
}

internal struct TxnInitRequest: Encodable {
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let operatingSystem: String
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let sdkVersion: String
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let layoutSchemaVersion: String

    enum CodingKeys: String, CodingKey {
        case operatingSystem = "operating_system"
        case sdkVersion = "sdk_version"
        case layoutSchemaVersion = "layout_schema_version"
    }
}
