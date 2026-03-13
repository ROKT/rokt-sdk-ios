import XCTest
@testable import Rokt_Widget

class TestUntriggeredRealTimeEvent: XCTestCase {

    func testInitialization_withAllValidParameters_succeeds() {
        let event = UntriggeredRealTimeEvent(
            triggerGuid: "guid",
            triggerEvent: "event",
            eventType: "type",
            payload: "payload"
        )
        XCTAssertNotNil(event)
        XCTAssertEqual(event.triggerGuid, "guid")
        XCTAssertEqual(event.triggerEvent, "event")
        XCTAssertEqual(event.eventType, "type")
        XCTAssertEqual(event.payload, "payload")
    }

    func testIsValid_whenAllPropertiesAreNonNil_returnsTrue() {
        let event = UntriggeredRealTimeEvent(
            triggerGuid: "guid",
            triggerEvent: "event",
            eventType: "type",
            payload: "payload"
        )
        XCTAssertTrue(event.isValid())
    }

    func testIsValid_whenTriggerGuidIsNil_returnsFalse() {
        let event = UntriggeredRealTimeEvent(
            triggerGuid: nil,
            triggerEvent: "event",
            eventType: "type",
            payload: "payload"
        )
        XCTAssertFalse(event.isValid())
    }

    func testIsValid_whenTriggerEventIsNil_returnsFalse() {
        let event = UntriggeredRealTimeEvent(
            triggerGuid: "guid",
            triggerEvent: nil,
            eventType: "type",
            payload: "payload"
        )
        XCTAssertFalse(event.isValid())
    }

    func testIsValid_whenEventTypeIsNil_returnsFalse() {
        let event = UntriggeredRealTimeEvent(
            triggerGuid: "guid",
            triggerEvent: "event",
            eventType: nil,
            payload: "payload"
        )
        XCTAssertFalse(event.isValid())
    }

    func testIsValid_whenPayloadIsNil_returnsFalse() {
        let event = UntriggeredRealTimeEvent(
            triggerGuid: "guid",
            triggerEvent: "event",
            eventType: "type",
            payload: nil
        )
        XCTAssertFalse(event.isValid())
    }

    func testIsValid_whenMultiplePropertiesAreNil_returnsFalse() {
        let event = UntriggeredRealTimeEvent(
            triggerGuid: nil,
            triggerEvent: "event",
            eventType: nil,
            payload: "payload"
        )
        XCTAssertFalse(event.isValid())
    }
}

class TestUntriggeredEventsContainer: XCTestCase {
    func testDecoding_validEventData_decodesSuccessfully() throws {
        let json = """
        {
          "eventData": {
            "parentGuid1": {
              "events": {
                "signalKey1": {
                  "eventType": "click",
                  "payload": "somePayload"
                },
                "signalKey2": {
                  "eventType": "view",
                  "payload": "anotherPayload"
                }
              }
            },
            "parentGuid2": {
              "events": {
                "signalKey3": {
                  "eventType": "hover",
                  "payload": "yetAnotherPayload"
                }
              }
            }
          }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UntriggeredEventsContainer.self, from: data)
        XCTAssertEqual(decoded.untriggeredEvents.count, 3)

        let expected = Set([
            UntriggeredRealTimeEvent(
                triggerGuid: "parentGuid1",
                triggerEvent: "signalKey1",
                eventType: "click",
                payload: "somePayload"
            ),
            UntriggeredRealTimeEvent(
                triggerGuid: "parentGuid1",
                triggerEvent: "signalKey2",
                eventType: "view",
                payload: "anotherPayload"
            ),
            UntriggeredRealTimeEvent(
                triggerGuid: "parentGuid2",
                triggerEvent: "signalKey3",
                eventType: "hover",
                payload: "yetAnotherPayload"
            )
        ])

        XCTAssertEqual(Set(decoded.untriggeredEvents), expected)
    }

    func testDecoding_invalidEventData_skipsInvalidEvents() throws {
        let json = """
        {
          "eventData": {
            "parentGuid1": {
              "events": {
                "signalKey1": {
                  "eventType": null,
                  "payload": "somePayload"
                },
                "signalKey2": {
                  "eventType": "view",
                  "payload": "anotherPayload"
                }
              }
            }
          }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UntriggeredEventsContainer.self, from: data)
        XCTAssertEqual(decoded.untriggeredEvents.count, 1)

        let expectedEvent = UntriggeredRealTimeEvent(
            triggerGuid: "parentGuid1",
            triggerEvent: "signalKey2",
            eventType: "view",
            payload: "anotherPayload"
        )
        XCTAssertEqual(decoded.untriggeredEvents.first, expectedEvent)
    }

    func testDecoding_emptyEventData_decodesEmptyArray() throws {
        let json = """
        {
          "eventData": {
            "parentGuid1": {
              "events": {}
            }
          }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UntriggeredEventsContainer.self, from: data)
        XCTAssertTrue(decoded.untriggeredEvents.isEmpty)
    }
}
