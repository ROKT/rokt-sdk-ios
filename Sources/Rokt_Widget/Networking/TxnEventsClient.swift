import Foundation

internal struct TxnEventsClient {
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

    func recordEvents(events: [TxnEvent], authToken: String?) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("events")

        let requestBody = TxnEventsRequest(
            channel: TxnEventsChannel(type: "msdk", sdkVersion: sdkVersion),
            events: events
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw TxnEventsClientError.bodyEncodingFailed
        }

        var headers = TxnRequestHeaders.common(accountId: accountId, authToken: authToken)
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

internal enum TxnEventsClientError: Error {
    case bodyEncodingFailed
}

internal struct TxnEventsRequest: Encodable {
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let channel: TxnEventsChannel
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let events: [TxnEvent]
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    // Mirrors the web controller's single_session: the mobile v2 flow uses one
    // session token for the whole batch.
    let singleSession: Bool = true

    enum CodingKeys: String, CodingKey {
        case channel
        case events
        case singleSession = "single_session"
    }
}

internal struct TxnEventsChannel: Encodable {
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let type: String
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case type
        case sdkVersion = "sdk_version"
    }
}

internal struct TxnEvent: Encodable, Equatable {
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let eventType: String
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let instanceId: String?
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    // Optional: omitted from the wire when the capture time is missing/unparseable
    // so the gateway defaults it to receive-time (mirrors web + Android).
    let timestamp: Int64?
    // periphery:ignore - encode-only; read by the synthesized Encodable, not by code
    let data: [String: TxnEventDataValue]?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case instanceId = "instance_id"
        case timestamp
        case data
    }
}
