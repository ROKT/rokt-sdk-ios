import Foundation

public struct RoktUXEventsPayload: Codable {
    public let integration: RoktIntegrationInfoDetails
    public let events: [RoktEventRequest]

    init(events: [RoktEventRequest]) {
        self.integration = RoktIntegrationInfo.shared.integration
        self.events = events
    }
}
