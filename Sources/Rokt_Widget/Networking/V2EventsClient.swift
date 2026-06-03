// periphery:ignore:all - referenced from Tests/ContractTests/V2EventsClientPactSpec.swift

import Foundation

internal struct V2EventsClient {
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

    func recordEvents(events: [V2Event]) async throws -> (Data?, HTTPURLResponse?) {
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

        let headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "Authorization": authToken,
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

internal enum V2EventsClientError: Error {
    case bodyEncodingFailed
}

internal struct V2EventsRequest: Encodable {
    let channel: V2EventsChannel
    let events: [V2Event]
}

internal struct V2EventsChannel: Encodable {
    let type: String
    let sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case type
        case sdkVersion = "sdk_version"
    }
}

internal struct V2Event: Encodable {
    let eventType: String
    let instanceId: String?
    let timestamp: Int64
    let data: [String: String]?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case instanceId = "instance_id"
        case timestamp
        case data
    }
}
