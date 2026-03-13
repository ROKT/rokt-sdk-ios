import Foundation
internal import RoktUXHelper

struct ProcessedEvent: Hashable, Equatable {
    let sessionId: String
    let parentGuid: String
    let eventType: RoktUXEventType
    let pageInstanceGuid: String
    let attributes: [RoktEventNameValue]
}

extension ProcessedEvent {
    init(_ event: RoktEventRequest) {
        self = .init(
            sessionId: event.sessionId,
            parentGuid: event.parentGuid,
            eventType: event.eventType,
            pageInstanceGuid: event.pageInstanceGuid,
            attributes: event.eventData
        )
    }

    private var attributesAsString: String {
        let attributesDict: [String: String] = attributes
            .map { $0.getDictionary() }
            .flatMap { $0 }
            .reduce([String: String]()) { (dict, tuple) in
                var nextDict = dict
                nextDict.updateValue(tuple.1, forKey: tuple.0)
                return nextDict
            }
        return attributesDict
            .sorted(by: { $0.0 < $1.0 })
            .map { "\($0):\($1)" }
            .joined(separator: "")
    }

    public func getHashString() -> String {
        return [sessionId, parentGuid, eventType.rawValue, pageInstanceGuid, attributesAsString]
            .joined(separator: "")
            .sha256()
    }
}
