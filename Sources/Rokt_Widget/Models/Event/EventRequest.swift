import Foundation
internal import RoktUXHelper

struct EventRequest: Codable, Hashable {
    let uuid: String
    let sessionId: String
    let eventType: RoktUXEventType
    let parentGuid: String
    let eventTime: String
    let attributes: [RoktEventNameValue]
    let metadata: [RoktEventNameValue]
    let pageInstanceGuid: String
    let jwtToken: String

    public enum CodingKeys: String, CodingKey {
        case uuid = "instanceGuid"
        case sessionId
        case eventType
        case parentGuid
        case eventTime
        case attributes
        case metadata
        case pageInstanceGuid
        case jwtToken = "token"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        eventType = try container.decode(RoktUXEventType.self, forKey: .eventType)
        parentGuid = try container.decode(String.self, forKey: .parentGuid)
        eventTime = try container.decode(String.self, forKey: .eventTime)
        attributes = try container.decode([RoktEventNameValue].self, forKey: .attributes)
        metadata = try container.decode([RoktEventNameValue].self, forKey: .metadata)
        pageInstanceGuid = try container.decode(String.self, forKey: .pageInstanceGuid)
        jwtToken = try container.decode(String.self, forKey: .jwtToken)
        uuid = try container.decode(String.self, forKey: .uuid)
    }

    public init(
        sessionId: String,
        eventType: RoktUXEventType,
        parentGuid: String,
        eventTime: Date = Date(),
        extraMetadata: [RoktEventNameValue] = [RoktEventNameValue](),
        attributes: [String: String] = [String: String](),
        pageInstanceGuid: String = "",
        jwtToken: String
    ) {
        self.uuid = UUID().uuidString
        self.sessionId = sessionId
        self.eventType = eventType
        self.parentGuid = parentGuid
        self.eventTime = EventDateFormatter.getDateString(eventTime)
        self.attributes = EventRequest.convertDictionaryToNameValue(attributes)
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
        let params: [String: Any] = [
            BE_SESSION_ID_KEY: sessionId,
            BE_PARENT_GUID_KEY: parentGuid,
            BE_PAGE_INSTANCE_GUID_KEY: pageInstanceGuid,
            BE_EVENT_TYPE_KEY: eventType.rawValue,
            BE_METADATA_KEY: getNameValueDictionary(metadata),
            BE_ATTRIBUTES_KEY: getNameValueDictionary(attributes)
        ]

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
