import Foundation

struct ProcessedEvent: Hashable, Equatable {
    let sessionId: String
    let parentGuid: String
    let eventType: RoktUXEventType
    let pageInstanceGuid: String
    let eventData: [RoktEventNameValue]
    let objectData: [String: String]?
}

extension ProcessedEvent {
    init(_ event: RoktEventRequest) {
        self = .init(
            sessionId: event.sessionId,
            parentGuid: event.parentGuid,
            eventType: event.eventType,
            pageInstanceGuid: event.pageInstanceGuid,
            eventData: event.eventData,
            objectData: event.objectData
        )
    }
}
