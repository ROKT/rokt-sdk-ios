import Foundation

internal struct InitClient {
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
            .appendingPathComponent("sessions")
            .appendingPathComponent("init")

        let requestBody = InitRequest(
            operatingSystem: operating_system,
            sdkVersion: sdkVersion,
            layoutSchemaVersion: layout_schema_version
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw InitClientError.bodyEncodingFailed
        }

        var headers = RequestHeaders.common(accountId: accountId, authToken: authToken)
        headers["x-request-id"] = UUID().uuidString

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

internal enum InitClientError: Error {
    case bodyEncodingFailed
}

internal struct InitRequest: Encodable {
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
