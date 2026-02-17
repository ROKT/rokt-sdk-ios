import XCTest
@testable import Rokt_Widget
internal import RoktUXHelper

final class TestROKTAPIHelperExtension: XCTestCase {
    // MARK: - Get Privacy Control Payload

    func test_getPrivacyControlPayload_attributeIsIncorrectType_returnsEmptyPayload() {
        let attributes = ["test": 123]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        XCTAssertTrue(privacyControls.isEmpty)
    }

    func test_getPrivacyControlPayload_noPrivacyKVPs_returnsEmptyPayload() {
        let attributes = ["email": "user@rokt.com"]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        XCTAssertTrue(privacyControls.isEmpty)
    }

    func test_getPrivacyControlPayload_allKVPsExist_returnsFullPayload() {
        let attributes = [
            kNoFunctional: "true",
            kNoTargeting: "false",
            kDoNotShareOrSell: "tRue",
            kGpcEnabled: "fALse"
        ]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: true,
            isNoTargeting: false,
            isDoNotShareOrSell: true,
            isGPCEnabled: false
        )
    }

    func test_getPrivacyControlPayload_incompleteKVPsExist_returnsPartialPayload() {
        let attributes = [kNoTargeting: "true"]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: nil,
            isNoTargeting: true,
            isDoNotShareOrSell: nil,
            isGPCEnabled: nil
        )
    }

    func test_getPrivacyControlPayload_withIncorrectValues_returnsEmptyPayload() {
        let attributes = [
            kNoFunctional: "hello",
            kNoTargeting: "world",
            kDoNotShareOrSell: "foo",
            kGpcEnabled: "bar"
        ]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        XCTAssertTrue(privacyControls.isEmpty)
    }

    private func assertPrivacyControlValues(
        privacyControls: [String: Bool],
        isNoFunctional: Bool?,
        isNoTargeting: Bool?,
        isDoNotShareOrSell: Bool?,
        isGPCEnabled: Bool?
    ) {
        XCTAssertEqual(privacyControls[kNoFunctional], isNoFunctional)
        XCTAssertEqual(privacyControls[kNoTargeting], isNoTargeting)
        XCTAssertEqual(privacyControls[kDoNotShareOrSell], isDoNotShareOrSell)
        XCTAssertEqual(privacyControls[kGpcEnabled], isGPCEnabled)
    }
}

// MARK: - Remove Privacy KVP

extension TestROKTAPIHelperExtension {
    func test_removeAllPrivacyControlData_removesRelevantData() {
        let attributes = [
            kNoFunctional: "true",
            kNoTargeting: "true",
            kDoNotShareOrSell: "true",
            kGpcEnabled: "false",
            "extraData": "true"
        ]

        let sanitisedPayload = RoktAPIHelper.removePrivacyControlAttributes(attributes: attributes)

        XCTAssertEqual(sanitisedPayload.count, 1)
    }
}

// MARK: - Add Realtime Events

extension TestROKTAPIHelperExtension {

    override func setUp() {
        super.setUp()
        RealTimeEventManager.shared.clearAllEvents()
    }

    override func tearDown() {
        RealTimeEventManager.shared.clearAllEvents()
        super.tearDown()
    }

    func test_addRealtimeEventsIfPresent_noEvents_paramsUnchanged() {
        let initialParams = ["existingKey": "existingValue"]

        let updatedParams = RoktAPIHelper.addRealtimeEventsIfPresent(to: initialParams)

        XCTAssertEqual(updatedParams.count, initialParams.count)
        XCTAssertEqual(updatedParams["existingKey"] as? String, "existingValue")
        XCTAssertNil(updatedParams["realTimeEvents"])
    }

    func test_addRealtimeEventsIfPresent_withEvents_addsEventsToParams() {
        let triggerGuid = "testParentGuid1"
        let triggerEventTypeRaw = "CaptureAttributes"
        let eventType = "typeA"
        let payload = "payload1"
        let eventTime = Date()

        let untriggeredEventResponse = UntriggeredRealTimeEvent(
            triggerGuid: triggerGuid,
            triggerEvent: triggerEventTypeRaw,
            eventType: eventType,
            payload: payload
        )
        RealTimeEventManager.shared.addUntriggeredEvents([untriggeredEventResponse])

        let eventRequest = createTestRoktEventRequest(
            parentGuid: triggerGuid,
            eventTypeRaw: triggerEventTypeRaw,
            eventTime: eventTime
        )
        RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: [eventRequest])

        RunLoop.current.run(until: Date().addingTimeInterval(1))

        let params: [String: Any] = ["existingKey": "existingValue"]
        let updatedParams = RoktAPIHelper.addRealtimeEventsIfPresent(to: params)

        XCTAssertNotNil(updatedParams["realTimeEvents"])
        guard let eventsDict = updatedParams["realTimeEvents"] as? [String: Any] else {
            XCTFail("realTimeEvents dictionary not found or is not the correct type")
            return
        }

        XCTAssertEqual(eventsDict["version"] as? String, "1.0")
        guard let actualEventsArray = eventsDict["events"] as? [[String: Any]] else {
            XCTFail("events array within realTimeEvents not found or is not the correct type")
            return
        }

        XCTAssertEqual(actualEventsArray.count, 1)
        let firstEvent = actualEventsArray[0]
        XCTAssertEqual(firstEvent["parentGuid"] as? String, triggerGuid)
        XCTAssertEqual(firstEvent["eventType"] as? String, eventType)
        XCTAssertEqual(firstEvent["payload"] as? String, payload)
        XCTAssertNotNil(firstEvent["eventTime"] as? String, EventDateFormatter.getDateString(eventTime))
    }

    private func createTestRoktEventRequest(parentGuid: String, eventTypeRaw: String, eventTime: Date) -> RoktEventRequest {
        let dummyEventType = RoktUXEventType(rawValue: eventTypeRaw) ?? RoktUXEventType.CaptureAttributes

        return RoktEventRequest(
            sessionId: "testSession",
            eventType: dummyEventType,
            parentGuid: parentGuid,
            eventTime: eventTime,
            jwtToken: "testToken"
        )
    }
    private func createTestRoktUXRealTimeEventResponse(
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
}
