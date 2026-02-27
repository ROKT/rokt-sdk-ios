import XCTest
@testable import Rokt_Widget
internal import RoktUXHelper

class RealTimeEventStoreMemoryTest: XCTestCase {

    var sut: RealtimeEventStoreMemory!

    // MARK: - Test Data Constants

    private let guid1 = "guid1"
    private let guid2 = "guid2"
    private let guid3 = "guid3"

    private let signalImpressionRawValue = RoktUXEventType.SignalImpression.rawValue
    private let signalResponseRawValue = RoktUXEventType.SignalResponse.rawValue
    private let signalLoadStartRawValue = RoktUXEventType.SignalLoadStart.rawValue

    private let finalType1 = "finalType1"
    private let finalType2 = "finalType2"
    private let finalType3 = "finalType3"
    private let finalTypeA = "finalTypeA"
    private let finalTypeB = "finalTypeB"
    private let et1 = "et1"
    private let et2 = "et2"

    private let payload1 = "payload1"
    private let payload2 = "payload2"
    private let payload3 = "payload3"
    private let payloadA = "payloadA"
    private let payloadB = "payloadB"
    private let p1 = "p1"
    private let p2 = "p2"

    override func setUp() {
        super.setUp()
        sut = RealtimeEventStoreMemory()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createRoktUXRealTimeEventResponse(
        triggerGuid: String?,
        triggerEvent: String?,
        eventType: String?,
        payload: String?
    ) -> UntriggeredRealTimeEvent {
        return UntriggeredRealTimeEvent(
            triggerGuid: triggerGuid,
            triggerEvent: triggerEvent,
            eventType: eventType,
            payload: payload
        )
    }

    private func createRoktEventRequest(
        parentGuid: String,
        eventType: RoktUXEventType,
        eventTime: Date = Date(),
        sessionId: String = "testSessionId",
        jwtToken: String = "testJwtToken"
    ) -> RoktEventRequest {
        return RoktEventRequest(
            sessionId: sessionId,
            eventType: eventType,
            parentGuid: parentGuid,
            eventTime: eventTime,
            jwtToken: jwtToken
        )
    }

    private func createRoktEventResponse(_ numberToReturn: Int) -> [RoktEventRequest] {
        var triggeredEvents: [RoktEventRequest] = []
        for i in 0..<numberToReturn {
            triggeredEvents.append(
                createRoktEventRequest(
                    parentGuid: "guid\(i)",
                    eventType: .SignalImpression,
                    eventTime: Date.distantPast.addingTimeInterval(TimeInterval(i))
                )
            )
        }
        return triggeredEvents
    }

    private func createUntriggeredEvents(_ numberToReturn: Int) -> [UntriggeredRealTimeEvent] {
        var untriggeredEvents: [UntriggeredRealTimeEvent] = []
        for i in 0..<numberToReturn {
            untriggeredEvents.append(
                createRoktUXRealTimeEventResponse(
                    triggerGuid: "guid\(i)",
                    triggerEvent: "SignalImpression",
                    eventType: "SignalImpression",
                    payload: ""
                )
            )
        }
        return untriggeredEvents
    }

    // MARK: - Tests for addUntriggeredEvents & markAsTriggered (indirectly testing getTriggeredEvents)

    func test_markAsTriggered_singleMatch_eventIsTriggered() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        let date = Date()
        let eventRequest = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!,
            eventTime: date
        )
        sut.markAsTriggered([eventRequest])

        let triggeredEvents = sut.getTriggeredEvents()
        XCTAssertEqual(triggeredEvents.count, 1)
        XCTAssertEqual(triggeredEvents.first, TriggeredRealTimeEvent(
            parentGuid: guid1,
            eventType: finalType1,
            eventTime: EventDateFormatter.getDateString(date),
            payload: payload1
        ))
    }

    func test_markAsTriggered_noMatch_guidMismatch() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        let eventRequest = createRoktEventRequest(
            parentGuid: guid2,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!
        )
        sut.markAsTriggered([eventRequest])

        XCTAssertTrue(sut.getTriggeredEvents().isEmpty)
    }

    func test_markAsTriggered_noMatch_eventTypeRawMismatch() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        let eventRequest = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalResponseRawValue)!
        )
        sut.markAsTriggered([eventRequest])

        XCTAssertTrue(sut.getTriggeredEvents().isEmpty)
    }

    func test_markAsTriggered_nilFieldsInUntriggered_noMatch() {
        let untriggeredEventNilGuid = createRoktUXRealTimeEventResponse(
            triggerGuid: nil,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEventNilGuid])
        let eventRequest = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!
        )
        sut.markAsTriggered([eventRequest])
        XCTAssertTrue(
            sut.getTriggeredEvents().isEmpty,
            "Should not match if untriggered triggerGuid is nil and request parentGuid is not"
        )

        sut.clear()

        let untriggeredEventNilType = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: nil,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEventNilType])
        sut.markAsTriggered([eventRequest])
        XCTAssertTrue(
            sut.getTriggeredEvents().isEmpty,
            "Should not match if untriggered triggerEvent is nil and request eventType is not"
        )
    }

    func test_markAsTriggered_multipleUntriggered_oneMatch() {
        let untriggeredEvent1 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        let untriggeredEvent2 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid2,
            triggerEvent: signalResponseRawValue,
            eventType: finalType2,
            payload: payload2
        )
        let untriggeredEvent3 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid3,
            triggerEvent: signalLoadStartRawValue,
            eventType: finalType3,
            payload: payload3
        )
        sut.addUntriggeredEvents([untriggeredEvent1, untriggeredEvent2, untriggeredEvent3])

        let date = Date()
        let eventRequest = createRoktEventRequest(
            parentGuid: guid2,
            eventType: RoktUXEventType(rawValue: signalResponseRawValue)!,
            eventTime: date
        )
        sut.markAsTriggered([eventRequest])

        let triggeredEvents = sut.getTriggeredEvents()
        XCTAssertEqual(triggeredEvents.count, 1)
        XCTAssertEqual(triggeredEvents.first, TriggeredRealTimeEvent(
            parentGuid: guid2,
            eventType: finalType2,
            eventTime: EventDateFormatter.getDateString(date),
            payload: payload2
        ))
    }

    func test_markAsTriggered_multipleEventRequests_multipleMatches() {
        let untriggeredEvent1 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalTypeA,
            payload: payloadA
        )
        let untriggeredEvent2 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid2,
            triggerEvent: signalResponseRawValue,
            eventType: finalTypeB,
            payload: payloadB
        )
        sut.addUntriggeredEvents([untriggeredEvent1, untriggeredEvent2])

        let date1 = Date()
        let date2 = Date(timeIntervalSinceNow: 10)

        let eventRequest1 = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!,
            eventTime: date1
        )
        let eventRequest2 = createRoktEventRequest(
            parentGuid: guid2,
            eventType: RoktUXEventType(rawValue: signalResponseRawValue)!,
            eventTime: date2
        )
        let eventRequest3 = createRoktEventRequest(
            parentGuid: guid3,
            eventType: RoktUXEventType(rawValue: signalLoadStartRawValue)!
        )

        sut.markAsTriggered([eventRequest1, eventRequest2, eventRequest3])

        let triggeredEvents = sut.getTriggeredEvents()
        XCTAssertEqual(triggeredEvents.count, 2)

        let expectedEvent1 = TriggeredRealTimeEvent(
            parentGuid: guid1,
            eventType: finalTypeA,
            eventTime: EventDateFormatter.getDateString(date1),
            payload: payloadA
        )
        let expectedEvent2 = TriggeredRealTimeEvent(
            parentGuid: guid2,
            eventType: finalTypeB,
            eventTime: EventDateFormatter.getDateString(date2),
            payload: payloadB
        )

        XCTAssertTrue(triggeredEvents.contains(expectedEvent1))
        XCTAssertTrue(triggeredEvents.contains(expectedEvent2))
    }

    func test_markAsTriggered_untriggeredEventsIsEmpty_noEventsTriggered() {
        let eventRequest = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!
        )
        sut.markAsTriggered([eventRequest])
        XCTAssertTrue(sut.getTriggeredEvents().isEmpty)
    }

    func test_markAsTriggered_inputTriggeredEventsIsEmpty_noEventsTriggered() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        sut.markAsTriggered([])
        XCTAssertTrue(sut.getTriggeredEvents().isEmpty)
    }

    func test_markAsTriggered_eventMarkedMultipleTimes_addedOncePerMarkingRequest() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        let date1 = Date()
        let eventRequest1 = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!,
            eventTime: date1
        )

        sut.markAsTriggered([eventRequest1])
        XCTAssertEqual(sut.getTriggeredEvents().count, 1, "Should be 1 triggered event after first marking")

        let date2 = Date(timeIntervalSinceNow: 60)
         let eventRequest2 = createRoktEventRequest(
             parentGuid: guid1,
             eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!,
             eventTime: date2
         )

        sut.markAsTriggered([eventRequest2])

        XCTAssertEqual(
            sut.getTriggeredEvents().count,
            2,
            "Should be 2 triggered events after second marking as untriggeredEvents are not cleared upon match"
        )

        let triggeredResults = sut.getTriggeredEvents()
        let expectedTriggeredEvent1 = TriggeredRealTimeEvent(
            parentGuid: guid1,
            eventType: finalType1,
            eventTime: EventDateFormatter.getDateString(date1),
            payload: payload1
        )
        let expectedTriggeredEvent2 = TriggeredRealTimeEvent(
            parentGuid: guid1,
            eventType: finalType1,
            eventTime: EventDateFormatter.getDateString(date2),
            payload: payload1
        )

        XCTAssertTrue(triggeredResults.contains(expectedTriggeredEvent1))
        XCTAssertTrue(triggeredResults.contains(expectedTriggeredEvent2))
    }

    func test_markMoreThanMaxAsTriggered_onlyMaxRetreived() {
        let maximumNumberOfUntriggeredEventsToStore: Int = maximumRealTimeEventsToStore
        let untriggeredEvents = createUntriggeredEvents(maximumNumberOfUntriggeredEventsToStore)
        print("Untriggered events: \(untriggeredEvents)")

        // Add maximumRealTimeEventsToStore untriggered events
        sut.addUntriggeredEvents(untriggeredEvents)

        let triggeredEvents = createRoktEventResponse(maximumNumberOfUntriggeredEventsToStore)
        print("Triggered events: \(triggeredEvents)")

        // Mark all as triggered
        sut.markAsTriggered(triggeredEvents)

        XCTAssertEqual(maximumNumberOfUntriggeredEventsToStore, sut.getTriggeredEvents().count)

        let extraGuid = "guid\(maximumNumberOfUntriggeredEventsToStore + 1)"

        let extraUntriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: extraGuid,
            triggerEvent: "SignalImpression",
            eventType: "",
            payload: ""
        )

        // Add one more event
        sut.addUntriggeredEvents([extraUntriggeredEvent])

        let extraEventToTrigger = createRoktEventRequest(
            parentGuid: extraGuid,
            eventType: .SignalImpression
        )

        // Mark latest event as triggered
        sut.markAsTriggered([extraEventToTrigger])

        XCTAssertEqual(maximumNumberOfUntriggeredEventsToStore, sut.getTriggeredEvents().count)
        XCTAssertTrue(sut.getTriggeredEvents().contains { $0.parentGuid == extraGuid })
        XCTAssertFalse(sut.getTriggeredEvents().contains { $0.parentGuid == "guid0" })
    }

    // MARK: - Tests for addUntriggeredEvents (implicitly tested above, direct test for count)

    func test_addUntriggeredEvents_addsToStore() {
        let untriggeredEvent1 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: et1,
            payload: p1
        )
        let untriggeredEvent2 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid2,
            triggerEvent: signalResponseRawValue,
            eventType: et2,
            payload: p2
        )

        sut.addUntriggeredEvents([untriggeredEvent1])
        let eventRequest1 = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!
        )
        sut.markAsTriggered([eventRequest1])
        XCTAssertEqual(sut.getTriggeredEvents().count, 1, "Should have 1 triggered event after adding one and marking.")

        sut.clear()

        sut.addUntriggeredEvents([untriggeredEvent1, untriggeredEvent2])
        let eventRequestG1 = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!
        )
        let eventRequestG2 = createRoktEventRequest(
            parentGuid: guid2,
            eventType: RoktUXEventType(rawValue: signalResponseRawValue)!
        )
        sut.markAsTriggered([eventRequestG1, eventRequestG2])
        XCTAssertEqual(sut.getTriggeredEvents().count, 2, "Should have 2 triggered events after adding two and marking both.")
    }

    func test_addUntriggeredEvents_addEmptyArray_noChange() {
        let initialUntriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: et1,
            payload: p1
        )
        sut.addUntriggeredEvents([initialUntriggeredEvent])

        sut.addUntriggeredEvents([])

        let eventRequest = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!
        )
        sut.markAsTriggered([eventRequest])
        XCTAssertEqual(
            sut.getTriggeredEvents().count,
            1,
            "Adding an empty array of untriggered events should not affect existing ones."
        )
    }

    // MARK: - Tests for clear

    func test_clear_removesAllEvents() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalType1,
            payload: payload1
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        let eventRequest = createRoktEventRequest(
            parentGuid: guid1,
            eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!
        )
        sut.markAsTriggered([eventRequest])
        XCTAssertFalse(sut.getTriggeredEvents().isEmpty, "Pre-condition: triggeredEvents should not be empty")

        sut.clear()
        XCTAssertTrue(sut.getTriggeredEvents().isEmpty, "Triggered events should be empty after clear.")

        sut.markAsTriggered([eventRequest])
        XCTAssertTrue(
            sut.getTriggeredEvents().isEmpty,
            "No events should be triggered after clear, as untriggered list should also be empty."
        )
    }

    func test_clear_whenAlreadyEmpty() {
        XCTAssertTrue(sut.getTriggeredEvents().isEmpty, "Pre-condition: triggeredEvents should be empty")
        sut.clear()
        XCTAssertTrue(
            sut.getTriggeredEvents().isEmpty,
            "Triggered events should remain empty after clearing an already empty store."
        )
    }
}
