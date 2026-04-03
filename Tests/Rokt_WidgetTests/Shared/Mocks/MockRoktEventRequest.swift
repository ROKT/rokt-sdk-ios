import Foundation
internal import RoktUXHelper

extension RoktEventRequest {
    static func mock(eventType: RoktUXEventType, parentGuid: String = "parentGuid") -> Self {
        .init(
            sessionId: "sessionId",
            eventType: eventType,
            parentGuid: parentGuid,
            jwtToken: "token"
        )
    }
}
