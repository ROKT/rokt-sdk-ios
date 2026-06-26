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
                timestamp: epochMilliseconds(from: event.eventTime),
                payload: event.payload
            )
        }
    }

    /// Response `event_data` → untriggered events for the store, consulted when the
    /// next placement fires (mirrors ``UntriggeredEventsContainer``'s flattening).
    static func untriggeredEvents(from eventData: [String: SelectEventDataEntry]) -> [UntriggeredRealTimeEvent] {
        var events: [UntriggeredRealTimeEvent] = []
        for (parentGuid, entry) in eventData {
            guard let signals = entry.events else { continue }
            for (signalKey, signal) in signals {
                events.append(
                    UntriggeredRealTimeEvent(
                        triggerGuid: parentGuid,
                        triggerEvent: signalKey,
                        eventType: signal.eventType,
                        payload: signal.payload
                    )
                )
            }
        }
        return events
    }

    // Mirrors TxnEventMapper: parse the stored ISO event time to epoch-ms, falling back to now.
    private static func epochMilliseconds(from eventTime: String) -> Int64 {
        if let date = EventDateFormatter.dateFormatter.date(from: eventTime) {
            return Int64(date.timeIntervalSince1970 * 1000)
        }
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
