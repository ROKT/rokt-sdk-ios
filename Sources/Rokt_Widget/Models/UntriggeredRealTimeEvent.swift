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
        self.untriggeredEvents = UntriggeredRealTimeEvent.flattenedValid(
            from: rawEventDataMap.mapValues { $0.events }
        )
    }

    enum CodingKeys: String, CodingKey {
        case eventData
    }
}

private struct RawEventData: Decodable {
    let events: [String: RawEvent]?
}

private struct RawEvent: Decodable, RealTimeEventSignal {
    let eventType: String?
    let payload: String?
}

// A decoded real-time-event signal shared by RawEvent and SelectRealTimeEvent.
internal protocol RealTimeEventSignal {
    var eventType: String? { get }
    var payload: String? { get }
}

extension UntriggeredRealTimeEvent {
    /// Flatten event_data into untriggered events, dropping invalid entries.
    static func flattenedValid<Signal: RealTimeEventSignal>(
        from eventData: [String: [String: Signal]?]
    ) -> [UntriggeredRealTimeEvent] {
        var events: [UntriggeredRealTimeEvent] = []
        for (parentGuid, signals) in eventData {
            guard let signals else { continue }
            for (signalKey, signal) in signals {
                events.append(UntriggeredRealTimeEvent(
                    triggerGuid: parentGuid,
                    triggerEvent: signalKey,
                    eventType: signal.eventType,
                    payload: signal.payload
                ))
            }
        }
        return events.filter { $0.isValid() }
    }
}
