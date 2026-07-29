// periphery:ignore:all

import Foundation

/// Maps real-time events between the event store and offers requests.
internal enum SelectEventMapper {

    /// Triggered events from the previous placement.
    static func requestEvents(from triggered: [TriggeredRealTimeEvent]) -> [SelectEvent] {
        triggered.map { event in
            SelectEvent(
                eventType: event.eventType,
                timestamp: EventDateFormatter.epochMilliseconds(from: event.eventTime),
                payload: event.payload
            )
        }
    }

    /// Response event_data → untriggered events stored for the next placement.
    static func untriggeredEvents(from eventData: [String: SelectEventDataEntry]) -> [UntriggeredRealTimeEvent] {
        UntriggeredRealTimeEvent.flattenedValid(from: eventData.mapValues { $0.events })
    }
}
