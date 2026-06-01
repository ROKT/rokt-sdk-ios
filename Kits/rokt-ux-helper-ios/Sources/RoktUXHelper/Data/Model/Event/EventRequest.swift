import Foundation

public struct RoktEventRequest: Codable, Hashable {
    public let uuid: String
    public let sessionId: String
    public let eventType: RoktUXEventType
    public let parentGuid: String
    public let eventTime: String
    public let eventData: [RoktEventNameValue]
    public let metadata: [RoktEventNameValue]
    public let objectData: [String: String]?
    public let pageInstanceGuid: String
    public let jwtToken: String

    public enum CodingKeys: String, CodingKey {
        case uuid = "instanceGuid"
        case sessionId
        case eventType
        case parentGuid
        case eventTime
        case eventData
        case metadata
        case objectData
        case pageInstanceGuid
        case jwtToken = "token"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        eventType = try container.decode(RoktUXEventType.self, forKey: .eventType)
        parentGuid = try container.decode(String.self, forKey: .parentGuid)
        eventTime = try container.decode(String.self, forKey: .eventTime)
        eventData = try container.decode([RoktEventNameValue].self, forKey: .eventData)
        metadata = try container.decode([RoktEventNameValue].self, forKey: .metadata)
        objectData = try container.decodeIfPresent([String: String].self, forKey: .objectData)
        pageInstanceGuid = try container.decode(String.self, forKey: .pageInstanceGuid)
        jwtToken = try container.decode(String.self, forKey: .jwtToken)
        uuid = try container.decode(String.self, forKey: .uuid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(parentGuid, forKey: .parentGuid)
        try container.encode(eventTime, forKey: .eventTime)
        try container.encode(eventData, forKey: .eventData)
        try container.encode(metadata, forKey: .metadata)

        // objectData is a generic payload extension for non-schema interactions such as
        // catalog and shoppable-ad events, so omit it when unused to keep the contract stable.
        if let objectData = objectData, !objectData.isEmpty {
            try container.encode(objectData, forKey: .objectData)
        }

        try container.encode(pageInstanceGuid, forKey: .pageInstanceGuid)
        try container.encode(jwtToken, forKey: .jwtToken)
    }

    public init(
        sessionId: String,
        eventType: RoktUXEventType,
        parentGuid: String,
        eventTime: Date = Date(),
        extraMetadata: [RoktEventNameValue] = [RoktEventNameValue](),
        eventData: [String: String] = [String: String](),
        objectData: [String: String]? = nil,
        pageInstanceGuid: String = "",
        jwtToken: String
    ) {
        self.uuid = UUID().uuidString
        self.sessionId = sessionId
        self.eventType = eventType
        self.parentGuid = parentGuid
        self.eventTime = EventDateFormatter.getDateString(eventTime)
        self.eventData = RoktEventRequest.convertDictionaryToNameValue(eventData)
        self.objectData = objectData
        self.pageInstanceGuid = pageInstanceGuid
        self.metadata = [RoktEventNameValue(name: BE_CLIENT_TIME_STAMP,
                                            value: EventDateFormatter.getDateString(eventTime)),
                         RoktEventNameValue(name: BE_CAPTURE_METHOD,
                                            value: kClientProvided)] + extraMetadata
        self.jwtToken = jwtToken
    }

    public var getParams: [String: Any] {
        (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self))) as? [String: Any] ?? [:]
    }

    public func getLog() -> String {
        var params: [String: Any] = [
            BE_SESSION_ID_KEY: sessionId,
            BE_PARENT_GUID_KEY: parentGuid,
            BE_PAGE_INSTANCE_GUID_KEY: pageInstanceGuid,
            BE_EVENT_TYPE_KEY: eventType.rawValue,
            BE_METADATA_KEY: getNameValueDictionary(metadata),
            BE_EVENT_DATA_KEY: getNameValueDictionary(eventData)
        ]

        // Only include objectData if it's not nil and not empty
        if let objectData = objectData, !objectData.isEmpty {
            params[BE_OBJECT_DATA_KEY] = objectData
        }

        guard let theJSONData = try? JSONSerialization.data(withJSONObject: params,
                                                            options: []),
              let jsonString = String(data: theJSONData, encoding: .utf8) else {
            return ""
        }
        return "RoktEventLog: \(jsonString)"
    }

    private func getNameValueDictionary(_ nameValues: [RoktEventNameValue]) -> [[String: Any]] {
        return nameValues.map { $0.getDictionary()}
    }

    private static func convertDictionaryToNameValue(_ from: [String: String]) -> [RoktEventNameValue] {
        return from.map { RoktEventNameValue(name: $0.key, value: $0.value)}
    }
}
