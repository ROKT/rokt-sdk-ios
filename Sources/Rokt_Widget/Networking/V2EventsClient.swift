import Foundation

internal struct V2EventsClient {
    let baseURL: URL
    let accountId: String
    let sdkVersion: String
    let deviceHeaders: [String: String]
    let httpClient: HTTPClientAdapter

    init(
        baseURL: URL,
        accountId: String,
        sdkVersion: String,
        deviceHeaders: [String: String] = [:],
        httpClient: HTTPClientAdapter = RoktHTTPClient()
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.deviceHeaders = deviceHeaders
        self.httpClient = httpClient
    }

    func recordEvents(events: [V2Event], authToken: String?) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("events")

        let requestBody = V2EventsRequest(
            channel: V2EventsChannel(type: "msdk", sdkVersion: sdkVersion),
            events: events
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw V2EventsClientError.bodyEncodingFailed
        }

        var headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "Content-Type": "application/json"
        ]
        // Authorization is optional: with no live token the server mints a fresh session.
        if let authToken, !authToken.isEmpty {
            headers["Authorization"] = authToken
        }
        for (key, value) in deviceHeaders {
            headers[key] = value
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

internal enum V2EventsClientError: Error {
    case bodyEncodingFailed
}

internal struct V2EventsRequest: Encodable {
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let channel: V2EventsChannel
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let events: [V2Event]
}

internal struct V2EventsChannel: Encodable {
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let type: String
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case type
        case sdkVersion = "sdk_version"
    }
}

internal struct V2Event: Encodable, Equatable {
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let eventType: String
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let instanceId: String?
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let timestamp: Int64
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let data: [String: TxnEventDataValue]?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case instanceId = "instance_id"
        case timestamp
        case data
    }
}
