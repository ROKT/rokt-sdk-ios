// periphery:ignore:all - referenced from Tests/ContractTests/V2EventsClientPactSpec.swift,
// which isn't part of the rokt-Example scheme that Periphery scans. See V2OffersClient
// for the rationale on why this lives in Sources/ rather than Tests/.

import Foundation

/// Client for the v2 sessions events endpoint on transactions-api.
///
/// Mirrors V2OffersClient — describes the v2 wire contract that mobile will
/// satisfy at v1→v2 migration time. Not yet wired into production: the SDK
/// still posts events via `/rokt-mobile/v1/*`. Lives in Sources/ so the
/// consumer pact in `Tests/ContractTests/V2EventsClientPactSpec.swift`
/// constrains the shipping SDK code rather than a test-only shadow.
///
/// Endpoint semantics (see transactions:apps/api/internal/events/handler.go):
///   - Session identity is conveyed solely via the `Authorization` JWT;
///     there is no session_id in the body.
///   - `events[].timestamp` is Unix epoch milliseconds (int64). RFC 3339
///     strings are accepted but deprecated and surface a warning on the
///     202 response.
///   - The response always includes a refreshed `session_token` (the
///     server may rotate it), `event_ids` for each accepted event, and
///     `errors` / `warnings` arrays (empty on the happy path).
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

/// Single event in a v2 RecordEvents batch.
///
/// `timestamp` is int64 Unix epoch milliseconds — the canonical wire
/// format. `data` is intentionally `[String: String]?` for now: the
/// server-side schema is `map[string]any`, but iOS event payloads in
/// practice carry only string values (e.g. `source_message_id`). Lift
/// the value type when a real consumer needs nested or numeric data.
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
