// periphery:ignore:all - referenced from Tests/ContractTests/V2EventsClientPactSpec.swift

import Foundation

internal struct V2EventsClient {
    let baseURL: URL
    let accountId: String
    let authToken: String
    let sdkVersion: String
    let urlSession: URLSession

    init(
        baseURL: URL,
        accountId: String,
        authToken: String,
        sdkVersion: String,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.authToken = authToken
        self.sdkVersion = sdkVersion
        self.urlSession = urlSession
    }

    func recordEvents(events: [V2Event]) async throws -> (Data, URLResponse) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("events")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(accountId, forHTTPHeaderField: "rokt-account-id")
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("iOS", forHTTPHeaderField: "rokt-platform-type")
        request.setValue("msdk-ios", forHTTPHeaderField: "rokt-integration-type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = V2EventsRequest(
            channel: V2EventsChannel(type: "msdk", sdkVersion: sdkVersion),
            events: events
        )
        request.httpBody = try JSONEncoder().encode(body)

        return try await urlSession.data(for: request)
    }
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
