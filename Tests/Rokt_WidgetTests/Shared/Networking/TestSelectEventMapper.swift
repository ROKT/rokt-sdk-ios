import XCTest
@testable import Rokt_Widget

/// Covers the real-time event bridge between the SDK store and the v2 offers
/// request/response: triggered events map to the request `events[]` shape, and the
/// response `event_data` flattens into untriggered events for the next call.
final class TestSelectEventMapper: XCTestCase {

    func test_requestEvents_mapsTriggeredEventToWireShape() throws {
        // Round-trip the event time through the formatter so the epoch-ms is exact.
        let eventTime = EventDateFormatter.dateFormatter.string(from: Date(timeIntervalSince1970: 1_782_484_201))
        let triggered = [
            TriggeredRealTimeEvent(parentGuid: "p", eventType: "impression", eventTime: eventTime, payload: "pl")
        ]

        let events = SelectEventMapper.requestEvents(from: triggered)

        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.eventType, "impression")
        XCTAssertNil(event.instanceId)
        XCTAssertEqual(event.timestamp, 1_782_484_201_000)
        XCTAssertEqual(event.data?["payload"], .string("pl"))
    }

    func test_requestEvents_fallsBackToNowWhenEventTimeUnparseable() {
        let triggered = [
            TriggeredRealTimeEvent(parentGuid: "p", eventType: "viewed", eventTime: "not-a-date", payload: "pl")
        ]

        let events = SelectEventMapper.requestEvents(from: triggered)

        // Unparseable time falls back to ~now rather than dropping the event.
        XCTAssertEqual(events.count, 1)
        XCTAssertGreaterThan(events.first?.timestamp ?? 0, 0)
    }

    func test_untriggeredEvents_flattensResponseEventData() throws {
        let json = """
        {
          "session_id": "s",
          "session_token": { "token": "t", "expires_at": 32503680000000 },
          "event_data": {
            "parent-1": { "token": "tok", "events": { "SignalResponse": { "event_type": "x", "payload": "y" } } }
          }
        }
        """
        let decoded = try JSONDecoder().decode(SelectResponse.self, from: Data(json.utf8))
        let eventData = try XCTUnwrap(decoded.eventData)

        let untriggered = SelectEventMapper.untriggeredEvents(from: eventData)

        XCTAssertEqual(untriggered.count, 1)
        let event = try XCTUnwrap(untriggered.first)
        XCTAssertEqual(event.triggerGuid, "parent-1")
        XCTAssertEqual(event.triggerEvent, "SignalResponse")
        XCTAssertEqual(event.eventType, "x")
        XCTAssertEqual(event.payload, "y")
        XCTAssertTrue(event.isValid())
    }

    func test_untriggeredEvents_isEmptyWhenEntryHasNoEvents() throws {
        let json = """
        {
          "session_id": "s",
          "session_token": { "token": "t", "expires_at": 32503680000000 },
          "event_data": { "parent-1": { "token": "tok" } }
        }
        """
        let decoded = try JSONDecoder().decode(SelectResponse.self, from: Data(json.utf8))
        let eventData = try XCTUnwrap(decoded.eventData)

        XCTAssertTrue(SelectEventMapper.untriggeredEvents(from: eventData).isEmpty)
    }
}
