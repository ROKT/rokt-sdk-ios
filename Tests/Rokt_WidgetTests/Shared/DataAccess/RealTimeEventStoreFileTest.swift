import XCTest
@testable import Rokt_Widget
internal import RoktUXHelper

class RealTimeEventStoreFileTest: XCTestCase {
    var sut: RealTimeEventStoreFile!
    let debounceInterval: TimeInterval = 0.5
    let expectationTimeout: TimeInterval = 1.0

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
        sut = RealTimeEventStoreFile()
    }

    override func tearDown() {
        sut.clear()
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

    // MARK: - Tests for addUntriggeredEvents & markAsTriggered (indirectly testing getTriggeredEvents)

    func test_markAsTriggered_singleMatch_eventIsTriggered() {
        let markExpectation = expectation(description: "Events marked and processed after debounce")

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

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 1)
            let expectedTriggeredEvent = TriggeredRealTimeEvent(
                parentGuid: self.guid1,
                eventType: self.finalType1,
                eventTime: EventDateFormatter.getDateString(date),
                payload: self.payload1
            )
            XCTAssertEqual(triggeredEvents.count, 1)
            XCTAssertEqual(triggeredEvents.first, expectedTriggeredEvent)
            markExpectation.fulfill()
        })
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
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
        let markExpectation = expectation(description: "One event matches and is marked as triggered")
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

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 1)
            XCTAssertEqual(triggeredEvents.first, TriggeredRealTimeEvent(
                parentGuid: self.guid2,
                eventType: self.finalType2,
                eventTime: EventDateFormatter.getDateString(date),
                payload: self.payload2
            ))

            markExpectation.fulfill()
        })
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
    }

    func test_markAsTriggered_multipleEventRequests_multipleMatches() {
        let markExpectation = expectation(description: "Multiple events match and are marked as triggered")
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

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 2)

            let expectedEvent1 = TriggeredRealTimeEvent(
                parentGuid: self.guid1,
                eventType: self.finalTypeA,
                eventTime: EventDateFormatter.getDateString(date1),
                payload: self.payloadA
            )
            let expectedEvent2 = TriggeredRealTimeEvent(
                parentGuid: self.guid2,
                eventType: self.finalTypeB,
                eventTime: EventDateFormatter.getDateString(date2),
                payload: self.payloadB
            )

            XCTAssertTrue(triggeredEvents.contains(expectedEvent1))
            XCTAssertTrue(triggeredEvents.contains(expectedEvent2))

            markExpectation.fulfill()
        })
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
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
        let markExpectation1 = expectation(description: "Should be 1 triggered event after first marking")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            XCTAssertEqual(self.sut.getTriggeredEvents().count, 1, "Should be 1 triggered event after first marking")

            markExpectation1.fulfill()
        })
        wait(for: [markExpectation1], timeout: expectationTimeout + 0.5)

        let date2 = Date(timeIntervalSinceNow: 60)
         let eventRequest2 = createRoktEventRequest(
             parentGuid: guid1,
             eventType: RoktUXEventType(rawValue: signalImpressionRawValue)!,
             eventTime: date2
         )

        sut.markAsTriggered([eventRequest2])
        let markExpectation2 =
            expectation(
                description: "Should be 2 triggered events after second marking as untriggeredEvents are not cleared upon match"
            )
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            let triggeredResults = self.sut.getTriggeredEvents()
            XCTAssertEqual(
                triggeredResults.count,
                2,
                "Should be 2 triggered events after second marking as untriggeredEvents are not cleared upon match"
            )

            let expectedTriggeredEvent1 = TriggeredRealTimeEvent(
                parentGuid: self.guid1,
                eventType: self.finalType1,
                eventTime: EventDateFormatter.getDateString(date1),
                payload: self.payload1
            )
            let expectedTriggeredEvent2 = TriggeredRealTimeEvent(
                parentGuid: self.guid1,
                eventType: self.finalType1,
                eventTime: EventDateFormatter.getDateString(date2),
                payload: self.payload1
            )

            XCTAssertTrue(triggeredResults.contains(expectedTriggeredEvent1))
            XCTAssertTrue(triggeredResults.contains(expectedTriggeredEvent2))

            markExpectation2.fulfill()
        })
        wait(for: [markExpectation2], timeout: expectationTimeout + 0.5)
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
        let markExpectation1 = expectation(description: "Should have 1 triggered event after adding one and marking.")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            XCTAssertEqual(self.sut.getTriggeredEvents().count, 1, "Should have 1 triggered event after adding one and marking.")

            markExpectation1.fulfill()
        })
        wait(for: [markExpectation1], timeout: expectationTimeout + 0.5)

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

        let markExpectation2 = expectation(description: "Should have 2 triggered events after adding two and marking both.")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            XCTAssertEqual(
                self.sut.getTriggeredEvents().count,
                2,
                "Should have 2 triggered events after adding two and marking both."
            )

            markExpectation2.fulfill()
        })
        wait(for: [markExpectation2], timeout: expectationTimeout + 0.5)
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

        let markExpectation1 =
            expectation(description: "Adding an empty array of untriggered events should not affect existing ones.")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            XCTAssertEqual(
                self.sut.getTriggeredEvents().count,
                1,
                "Adding an empty array of untriggered events should not affect existing ones."
            )

            markExpectation1.fulfill()
        })
        wait(for: [markExpectation1], timeout: expectationTimeout + 0.5)
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
        let expectationNotEmpty = expectation(description: "Pre-condition: triggeredEvents should not be empty")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            XCTAssertFalse(self.sut.getTriggeredEvents().isEmpty, "Pre-condition: triggeredEvents should not be empty")

            expectationNotEmpty.fulfill()
        })
        wait(for: [expectationNotEmpty], timeout: expectationTimeout + 0.5)

        sut.clear()
        let expectationEmpty = expectation(description: "Triggered events should be empty after clear.")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            XCTAssertTrue(self.sut.getTriggeredEvents().isEmpty, "Triggered events should be empty after clear.")

            expectationEmpty.fulfill()
        })
        wait(for: [expectationEmpty], timeout: expectationTimeout + 0.5)

        sut.markAsTriggered([eventRequest])

        let expectationEmptyAfterTrigger =
            expectation(description: "No events should be triggered after clear, as untriggered list should also be empty.")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout, execute: {
            XCTAssertTrue(
                self.sut.getTriggeredEvents().isEmpty,
                "No events should be triggered after clear, as untriggered list should also be empty."
            )

            expectationEmptyAfterTrigger.fulfill()
        })
        wait(for: [expectationEmptyAfterTrigger], timeout: expectationTimeout + 0.5)
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
