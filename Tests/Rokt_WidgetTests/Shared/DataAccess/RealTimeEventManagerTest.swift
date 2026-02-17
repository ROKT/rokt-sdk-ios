import XCTest
@testable import Rokt_Widget
internal import RoktUXHelper

class RealTimeEventManagerTest: XCTestCase {
    let sut = RealTimeEventManager.shared
    let debounceInterval: TimeInterval = 0.5
    let expectationTimeout: TimeInterval = 1.0

    // MARK: - Test Data Constants

    private let guid1 = "guid1"
    private let guid2 = "guid2"
    private let anyGuid = "anyGuid"
    private let guidUnique = "guidUnique"
    private let guidToMark = "guidToMark"
    private let guidClear = "guidClear"
    private let validEventGuidConst = "validGuid"
    private let anotherGuidConst = "anotherGuid"
    private let yetAnotherGuidConst = "yetAnotherGuid"
    private let finalGuidConst = "finalGuid"
    private let g1Const = "g1"
    private let g2Const = "g2"
    private let g3Const = "g3"
    private let g4Const = "g4"

    private let finalImpressionTypeConst = "FinalImpressionType"
    private let impressionTypeConst = "ImpressionType"
    private let responseTypeConst = "ResponseType"
    private let activationTypeConst = "ActivationType"
    private let loadStartTypeConst = "LoadStartType"
    private let dismissalTypeConst = "DismissalType"
    private let validStoredEventTypeConst = "ValidStoredEventType"
    private let someTypeConst = "SomeType"
    private let anotherTypeConst = "AnotherType"
    private let finalTypeConst = "FinalType"
    private let t1Const = "t1"
    private let t2Const = "t2"
    private let t3Const = "t3"
    private let t4Const = "t4"

    private let impressionPayloadConst = "ImpressionPayload"
    private let payload1Const = "Payload1"
    private let payload2Const = "Payload2"
    private let activationPayloadConst = "ActivationPayload"
    private let loadStartPayloadConst = "LoadStartPayload"
    private let dismissalPayloadConst = "DismissalPayload"
    private let validPayloadConst = "ValidPayload"
    private let somePayloadConst = "SomePayload"
    private let anotherPayloadConst = "AnotherPayload"
    private let yetAnotherPayloadConst = "YetAnotherPayload"
    private let p1Const = "p1"
    private let p2Const = "p2"
    private let p3Const = "p3"
    private let p4Const = "p4"

    private let e1RawValue = "e1"

    private let signalImpressionRawValue = RoktUXEventType.SignalImpression.rawValue
    private let signalResponseRawValue = RoktUXEventType.SignalResponse.rawValue
    private let signalActivationRawValue = RoktUXEventType.SignalActivation.rawValue
    private let signalLoadStartRawValue = RoktUXEventType.SignalLoadStart.rawValue
    private let signalDismissalRawValue = RoktUXEventType.SignalDismissal.rawValue
    private let signalViewedRawValue = RoktUXEventType.SignalViewed.rawValue
    private let signalInitializeRawValue = RoktUXEventType.SignalInitialize.rawValue

    // MARK: - Test Lifecycle

    override func setUp() {
        super.setUp()
        let clearExpectation = expectation(description: "Clear events in setup")
        sut.clearAllEvents()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 0.5)
    }

    override func tearDown() {
        let clearExpectation = expectation(description: "Clear events in tearDown")
        sut.clearAllEvents()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 0.5)
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

    // MARK: - Test Cases

    func testAddUntriggeredEventsThenMarkAndGetThem() {
        let markExpectation = expectation(description: "Events marked and processed after debounce")

        let untriggeredEventResponse = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: finalImpressionTypeConst,
            payload: impressionPayloadConst
        )
        sut.addUntriggeredEvents([untriggeredEventResponse])

        let eventTime = Date()
        let roktEventRequest = createRoktEventRequest(
            parentGuid: guid1,
            eventType: .SignalImpression,
            eventTime: eventTime
        )
        sut.markEventsAsTriggered(triggeredEvents: [roktEventRequest])

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 1)
            let expectedTriggeredEvent = TriggeredRealTimeEvent(
                parentGuid: self.guid1,
                eventType: self.finalImpressionTypeConst,
                eventTime: EventDateFormatter.getDateString(eventTime),
                payload: self.impressionPayloadConst
            )
            XCTAssertEqual(triggeredEvents.first, expectedTriggeredEvent)
            markExpectation.fulfill()
        }
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
    }

    func testAddMultipleUntriggeredEventsAndMarkOne() {
        let markExpectation = expectation(description: "One of multiple events marked after debounce")

        let untriggeredEvent1 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid1,
            triggerEvent: signalImpressionRawValue,
            eventType: impressionTypeConst,
            payload: payload1Const
        )
        let untriggeredEvent2 = createRoktUXRealTimeEventResponse(
            triggerGuid: guid2,
            triggerEvent: signalResponseRawValue,
            eventType: responseTypeConst,
            payload: payload2Const
        )
        sut.addUntriggeredEvents([untriggeredEvent1, untriggeredEvent2])

        let eventTime = Date()
        let roktEventRequestToMark = createRoktEventRequest(
            parentGuid: guid2,
            eventType: .SignalResponse,
            eventTime: eventTime
        )
        sut.markEventsAsTriggered(triggeredEvents: [roktEventRequestToMark])

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 1)
            let expectedTriggeredEvent = TriggeredRealTimeEvent(
                parentGuid: self.guid2,
                eventType: self.responseTypeConst,
                eventTime: EventDateFormatter.getDateString(eventTime),
                payload: self.payload2Const
            )
            XCTAssertEqual(triggeredEvents.first, expectedTriggeredEvent)
            markExpectation.fulfill()
        }
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
    }

    func testAddEmptyArrayOfUntriggeredEvents() {
        let markExpectation = expectation(description: "No events triggered for empty untriggered add")
        sut.addUntriggeredEvents([])

        let roktEventRequest = createRoktEventRequest(parentGuid: anyGuid, eventType: .SignalViewed)
        sut.markEventsAsTriggered(triggeredEvents: [roktEventRequest])

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertTrue(triggeredEvents.isEmpty, "No events should be triggered if an empty array was added.")
            markExpectation.fulfill()
        }
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
    }

    func testGetTriggeredEventsWhenNoneMarked() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guidUnique,
            triggerEvent: signalActivationRawValue,
            eventType: activationTypeConst,
            payload: activationPayloadConst
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        let triggeredEvents = sut.getTriggeredEvents()
        XCTAssertTrue(triggeredEvents.isEmpty, "Should return empty if no events have been marked as triggered.")
    }

    func testGetTriggeredEventsInitiallyIsEmpty() {
        let triggeredEvents = sut.getTriggeredEvents()
        XCTAssertTrue(triggeredEvents.isEmpty, "Initially, there should be no triggered events.")
    }

    func testMarkEventsAsTriggeredWithEmptyRequestArray() {
        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guidToMark,
            triggerEvent: signalLoadStartRawValue,
            eventType: loadStartTypeConst,
            payload: loadStartPayloadConst
        )
        sut.addUntriggeredEvents([untriggeredEvent])
        sut.markEventsAsTriggered(triggeredEvents: [])

        XCTAssertTrue(sut.getTriggeredEvents().isEmpty)
        let emptyMarkExpectation = expectation(description: "No events triggered for empty mark request")
        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            XCTAssertTrue(
                self.sut.getTriggeredEvents().isEmpty,
                "No events should be triggered if the marking request array is empty."
            )
            emptyMarkExpectation.fulfill()
        }
        wait(for: [emptyMarkExpectation], timeout: expectationTimeout + 0.5)
    }

    func testClearAllEventsEmptiesStoreAndCancelsDebounce() {
        let clearExpectation = expectation(description: "Events cleared and debounce cancelled")

        let untriggeredEvent = createRoktUXRealTimeEventResponse(
            triggerGuid: guidClear,
            triggerEvent: signalDismissalRawValue,
            eventType: dismissalTypeConst,
            payload: dismissalPayloadConst
        )
        sut.addUntriggeredEvents([untriggeredEvent])

        let roktEventRequest = createRoktEventRequest(
            parentGuid: guidClear,
            eventType: .SignalDismissal
        )
        sut.markEventsAsTriggered(triggeredEvents: [roktEventRequest])

        sut.clearAllEvents()

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            XCTAssertTrue(self.sut.getTriggeredEvents().isEmpty, "Triggered events should be empty after clearAllEvents.")
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: expectationTimeout + 0.5)
    }

    func testClearAllEventsWhenAlreadyEmpty() {
        let clearExpectation = expectation(description: "Clear when empty finished")
        XCTAssertTrue(sut.getTriggeredEvents().isEmpty, "Pre-condition: Store should be empty.")
        sut.clearAllEvents()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             XCTAssertTrue(
                 self.sut.getTriggeredEvents().isEmpty,
                 "Store should remain empty after clearing an already empty store."
             )
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 0.5)
    }
}

// MARK: - isValid() specific tests

extension RealTimeEventManagerTest {

    func testAddUntriggeredEvents_onlyValidEventsAreStored() {
        let markExpectation = expectation(description: "Only valid events are stored and marked")

        let validEventResponse = createRoktUXRealTimeEventResponse(
            triggerGuid: validEventGuidConst,
            triggerEvent: signalViewedRawValue,
            eventType: validStoredEventTypeConst,
            payload: validPayloadConst
        )
        let invalidEventResponseNilGuid = createRoktUXRealTimeEventResponse(
            triggerGuid: nil,
            triggerEvent: signalActivationRawValue,
            eventType: someTypeConst,
            payload: somePayloadConst
        )
        sut.addUntriggeredEvents([
            invalidEventResponseNilGuid,
            validEventResponse
        ])

        let eventTime = Date()
        let roktEventRequestForValid = createRoktEventRequest(
            parentGuid: validEventGuidConst,
            eventType: RoktUXEventType(rawValue: signalViewedRawValue)!,
            eventTime: eventTime
        )
        sut.markEventsAsTriggered(triggeredEvents: [roktEventRequestForValid])

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 1, "Only the valid event should have been stored and thus marked.")
            let expectedTriggeredEvent = TriggeredRealTimeEvent(
                parentGuid: self.validEventGuidConst,
                eventType: self.validStoredEventTypeConst,
                eventTime: EventDateFormatter.getDateString(eventTime),
                payload: self.validPayloadConst
            )
            XCTAssertEqual(triggeredEvents.first, expectedTriggeredEvent)
            markExpectation.fulfill()
        }
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
    }

    func testAddUntriggeredEvents_allInvalidEvents_noneAreStored() {
        let markExpectation = expectation(description: "No invalid events are stored or marked")

        let invalidEvent1 = createRoktUXRealTimeEventResponse(
            triggerGuid: nil,
            triggerEvent: e1RawValue,
            eventType: t1Const,
            payload: p1Const
        )
        sut.addUntriggeredEvents([invalidEvent1])

        let roktEventRequest = createRoktEventRequest(
            parentGuid: g2Const,
            eventType: RoktUXEventType(rawValue: e1RawValue) ?? .SignalViewed
        )
        sut.markEventsAsTriggered(triggeredEvents: [roktEventRequest])

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertTrue(triggeredEvents.isEmpty, "No events should be triggered if all added untriggered events were invalid.")
            markExpectation.fulfill()
        }
        wait(for: [markExpectation], timeout: expectationTimeout + 0.5)
    }
}

// MARK: - Debounce specific tests

extension RealTimeEventManagerTest {
    func testMarkEventsAsTriggered_debounceAccumulatesEvents() {
        let debounceTestExpectation = expectation(description: "Debounced calls accumulate events")

        let event1Guid = "debounceGuid1"
        let event1TriggerRaw = RoktUXEventType.SignalImpression.rawValue
        let event1Type = "DebounceType1"
        let event1Payload = "DebouncePayload1"
        let event1Time = Date()

        let event2Guid = "debounceGuid2"
        let event2TriggerRaw = RoktUXEventType.SignalResponse.rawValue
        let event2Type = "DebounceType2"
        let event2Payload = "DebouncePayload2"
        let event2Time = Date(timeIntervalSinceNow: 0.05)

        sut.addUntriggeredEvents([
            createRoktUXRealTimeEventResponse(
                triggerGuid: event1Guid,
                triggerEvent: event1TriggerRaw,
                eventType: event1Type,
                payload: event1Payload
            ),
            createRoktUXRealTimeEventResponse(
                triggerGuid: event2Guid,
                triggerEvent: event2TriggerRaw,
                eventType: event2Type,
                payload: event2Payload
            )
        ])

        let request1 = createRoktEventRequest(parentGuid: event1Guid, eventType: .SignalImpression, eventTime: event1Time)
        let request2 = createRoktEventRequest(parentGuid: event2Guid, eventType: .SignalResponse, eventTime: event2Time)

        sut.markEventsAsTriggered(triggeredEvents: [request1])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sut.markEventsAsTriggered(triggeredEvents: [request2])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + expectationTimeout) {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 2, "Both events should be triggered after debounce.")

            let expectedTriggered1 = TriggeredRealTimeEvent(
                parentGuid: event1Guid,
                eventType: event1Type,
                eventTime: EventDateFormatter.getDateString(event1Time),
                payload: event1Payload
            )
            let expectedTriggered2 = TriggeredRealTimeEvent(
                parentGuid: event2Guid,
                eventType: event2Type,
                eventTime: EventDateFormatter.getDateString(event2Time),
                payload: event2Payload
            )

            XCTAssertTrue(triggeredEvents.contains(expectedTriggered1))
            XCTAssertTrue(triggeredEvents.contains(expectedTriggered2))
            debounceTestExpectation.fulfill()
        }

        wait(for: [debounceTestExpectation], timeout: expectationTimeout + 0.5)
    }

    func testMarkEventsAsTriggered_timerResetsOnNewCall() {
        let debounceResetExpectation = expectation(description: "Debounce timer resets on new call")

        let event1Guid = "resetGuid1"
        let event1TriggerRaw = RoktUXEventType.SignalViewed.rawValue
        let event1Type = "ResetType1"
        let event1Payload = "ResetPayload1"
        let event1Time = Date()

        let event2Guid = "resetGuid2"
        let event2TriggerRaw = RoktUXEventType.SignalActivation.rawValue
        let event2Type = "ResetType2"
        let event2Payload = "ResetPayload2"
        let event2Time = Date(timeIntervalSinceNow: debounceInterval * 0.5)

        sut.addUntriggeredEvents([
            createRoktUXRealTimeEventResponse(
                triggerGuid: event1Guid,
                triggerEvent: event1TriggerRaw,
                eventType: event1Type,
                payload: event1Payload
            ),
            createRoktUXRealTimeEventResponse(
                triggerGuid: event2Guid,
                triggerEvent: event2TriggerRaw,
                eventType: event2Type,
                payload: event2Payload
            )
        ])

        let request1 = createRoktEventRequest(parentGuid: event1Guid, eventType: .SignalViewed, eventTime: event1Time)
        let request2 = createRoktEventRequest(parentGuid: event2Guid, eventType: .SignalActivation, eventTime: event2Time)

        sut.markEventsAsTriggered(triggeredEvents: [request1])

        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval * 0.5) {
            self.sut.markEventsAsTriggered(triggeredEvents: [request2])
        }

        let totalWaitTime = (debounceInterval * 0.5) + expectationTimeout

        DispatchQueue.main.asyncAfter(deadline: .now() + totalWaitTime) {
            let triggeredEvents = self.sut.getTriggeredEvents()
            XCTAssertEqual(triggeredEvents.count, 2, "Both events should be triggered after the reset debounce.")

            let expectedTriggered1 = TriggeredRealTimeEvent(
                parentGuid: event1Guid,
                eventType: event1Type,
                eventTime: EventDateFormatter.getDateString(event1Time),
                payload: event1Payload
            )
            let expectedTriggered2 = TriggeredRealTimeEvent(
                parentGuid: event2Guid,
                eventType: event2Type,
                eventTime: EventDateFormatter.getDateString(event2Time),
                payload: event2Payload
            )

            XCTAssertTrue(triggeredEvents.contains(expectedTriggered1))
            XCTAssertTrue(triggeredEvents.contains(expectedTriggered2))
            debounceResetExpectation.fulfill()
        }
        wait(for: [debounceResetExpectation], timeout: totalWaitTime + 0.5)
    }
}
