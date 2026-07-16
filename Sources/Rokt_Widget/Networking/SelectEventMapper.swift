// periphery:ignore:all - offers real-time event mapping

import Foundation

/// Bridges the SDK real-time event store and the v2 offers request/response.
///
/// The request `events[]` element (``SelectEvent``) encodes to the
/// `/v2/sessions/events` wire shape: `event_type`, epoch-ms `timestamp`,
/// `data.payload`, matching Android.
internal enum SelectEventMapper {

    /// Triggered events from the previous placement → the offers request `events[]`.
    static func requestEvents(from triggered: [TriggeredRealTimeEvent]) -> [SelectEvent] {
        triggered.map { event in
            SelectEvent(
                eventType: event.eventType,
                timestamp: EventDateFormatter.epochMilliseconds(from: event.eventTime),
                payload: event.payload
            )
        }
    }

    /// Response `event_data` → untriggered events for the store, consulted when the next
    /// placement fires. Uses the shared flatten/validate path
    /// (`UntriggeredRealTimeEvent.flattenedValid`).
    static func untriggeredEvents(from eventData: [String: SelectEventDataEntry]) -> [UntriggeredRealTimeEvent] {
        UntriggeredRealTimeEvent.flattenedValid(from: eventData.mapValues { $0.events })
    }
}
