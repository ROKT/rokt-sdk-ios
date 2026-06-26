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

    /// Response `event_data` → untriggered events for the store, consulted when the
    /// next placement fires. The flattening parallels ``UntriggeredEventsContainer`` (the
    /// v1 path), but stays separate because v1 decodes camelCase `eventType` while v2
    /// decodes snake_case `event_type`. Entries missing required fields are dropped here,
    /// matching that sibling.
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
        return events.filter { $0.isValid() }
    }
}
