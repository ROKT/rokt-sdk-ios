import Foundation

struct UntriggeredRealTimeEvent: Codable, Hashable {
    let triggerGuid: String?
    let triggerEvent: String?
    let eventType: String?
    let payload: String?

    func isValid() -> Bool {
        if triggerGuid == nil || triggerEvent == nil || eventType == nil || payload == nil {
            return false
        }
        return true
    }
}

struct UntriggeredEventsContainer: Decodable {
    let untriggeredEvents: [UntriggeredRealTimeEvent]

    init(from decoder: Decoder) throws {
        let rootContainer = try decoder.container(keyedBy: CodingKeys.self)
        let rawEventDataMap = try rootContainer.decode([String: RawEventData].self, forKey: .eventData)

        var parsedEvents: [UntriggeredRealTimeEvent] = []

        for (parentGuid, individualRawData) in rawEventDataMap {
            if let actualEvents = individualRawData.events {
                for (signalKey, rawSignalEvent) in actualEvents {
                    let event = UntriggeredRealTimeEvent(
                        triggerGuid: parentGuid,
                        triggerEvent: signalKey,
                        eventType: rawSignalEvent.eventType,
                        payload: rawSignalEvent.payload
                    )
                    if event.isValid() {
                        parsedEvents.append(event)
                    }
                }
            }
        }

        self.untriggeredEvents = parsedEvents
    }

    enum CodingKeys: String, CodingKey {
        case eventData
    }
}

private struct RawEventData: Decodable {
    let events: [String: RawEvent]?
}

private struct RawEvent: Decodable {
    let eventType: String?
    let payload: String?
}
