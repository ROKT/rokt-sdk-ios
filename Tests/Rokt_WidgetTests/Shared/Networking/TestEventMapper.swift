import XCTest
internal import RoktUXHelper
@testable import Rokt_Widget

final class TestEventMapper: XCTestCase {

    private let eventTime = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeRequest(
        eventType: RoktUXEventType,
        eventData: [String: String] = [:],
        objectData: [String: String]? = nil,
        parentGuid: String = "parent-1",
        pageInstanceGuid: String = "page-1",
        jwtToken: String = "jwt-1"
    ) -> RoktEventRequest {
        RoktEventRequest(
            sessionId: "session-1",
            eventType: eventType,
            parentGuid: parentGuid,
            eventTime: eventTime,
            eventData: eventData,
            objectData: objectData,
            pageInstanceGuid: pageInstanceGuid,
            jwtToken: jwtToken
        )
    }

    func test_mapsEventTypeVocabulary() {
        let cases: [(RoktUXEventType, String)] = [
            (.SignalImpression, "impression"),
            (.SignalViewed, "viewed"),
            (.SignalInitialize, "signal_initialize"),
            (.SignalLoadStart, "load_start"),
            (.SignalLoadComplete, "load_complete"),
            (.SignalResponse, "signal_response"),
            (.SignalDismissal, "dismissal"),
            (.SignalUserInteraction, "user_interaction"),
            (.SignalCartItemInstantPurchaseInitiated, "cart_item_instant_purchase_initiated"),
            (.SignalCartItemInstantPurchase, "cart_item_instant_purchase"),
            (.SignalCartItemInstantPurchaseFailure, "cart_item_instant_purchase_failure")
        ]

        for (eventType, expected) in cases {
            let event = EventMapper.event(from: makeRequest(eventType: eventType))
            XCTAssertEqual(event?.eventType, expected, "Unexpected wire type for \(eventType)")
        }
    }

    func test_gatedResponse_mapsToSignalResponseWithMarker() {
        let event = EventMapper.event(from: makeRequest(eventType: .SignalGatedResponse))

        XCTAssertEqual(event?.eventType, "signal_response")
        XCTAssertEqual(event?.data?["gated"], .string("true"))
    }

    func test_activation_mapsToUserInteractionWithType() {
        let event = EventMapper.event(from: makeRequest(eventType: .SignalActivation))

        XCTAssertEqual(event?.eventType, "user_interaction")
        XCTAssertEqual(event?.data?["interactionType"], .string("activation"))
    }

    func test_diagnosticAndInstantPurchaseDismissal_areDropped() {
        XCTAssertNil(EventMapper.event(from: makeRequest(eventType: .SignalSdkDiagnostic)))
        XCTAssertNil(EventMapper.event(from: makeRequest(eventType: .SignalInstantPurchaseDismissal)))
    }

    func test_instanceIdAndTimestampAreCarried() {
        let request = makeRequest(eventType: .SignalImpression)
        let event = EventMapper.event(from: request)

        XCTAssertEqual(event?.instanceId, request.uuid)
        XCTAssertEqual(event?.timestamp, 1_700_000_000_000)
    }

    func test_attributesAreFlattenedAndMetadataMapped() {
        let event = EventMapper.event(from: makeRequest(
            eventType: .SignalImpression,
            eventData: ["source_message_id": "abc"]
        ))

        XCTAssertEqual(event?.data?["source_message_id"], .string("abc"))
        // captureMethod metadata becomes capture_method; the clientTimeStamp entry is promoted to timestamp.
        XCTAssertEqual(event?.data?["capture_method"], .string("ClientProvided"))
        XCTAssertNil(event?.data?["clientTimeStamp"])
    }

    func test_reservedKeysAreAlwaysPresentAndWinOverAttributes() {
        let event = EventMapper.event(from: makeRequest(
            eventType: .SignalImpression,
            eventData: ["parent_id": "spoofed", "token": "spoofed"],
            parentGuid: "real-parent",
            pageInstanceGuid: "real-page",
            jwtToken: "real-token"
        ))

        XCTAssertEqual(event?.data?["parent_id"], .string("real-parent"))
        XCTAssertEqual(event?.data?["token"], .string("real-token"))
        XCTAssertEqual(event?.data?["page_instance_guid"], .string("real-page"))
    }

    func test_emptyPageInstanceGuid_isOmitted() {
        let event = EventMapper.event(from: makeRequest(
            eventType: .SignalImpression,
            pageInstanceGuid: ""
        ))

        XCTAssertNil(event?.data?["page_instance_guid"])
    }

    func test_objectDataIsFlattenedIntoData() {
        let event = EventMapper.event(from: makeRequest(
            eventType: .SignalImpression,
            objectData: ["custom_field": "value"]
        ))

        XCTAssertEqual(event?.data?["custom_field"], .string("value"))
    }

    func test_captureAttributes_nestsAttributesAndAddsMarker() {
        let event = EventMapper.event(from: makeRequest(
            eventType: .CaptureAttributes,
            eventData: ["email": "a@b.com", "token": "should-stay-nested"]
        ))

        XCTAssertEqual(event?.eventType, "capture_attributes")
        XCTAssertEqual(event?.data?["sdk_event"], .string("captureAttributes"))
        XCTAssertEqual(event?.data?["attributes"], .object(["email": "a@b.com", "token": "should-stay-nested"]))
        // The nested partner token must not leak into the reserved top-level token.
        XCTAssertEqual(event?.data?["token"], .string("jwt-1"))
    }

    func test_eventRequestOverload_mapsCaptureAttributes() {
        let request = EventRequest(
            sessionId: "session-1",
            eventType: .CaptureAttributes,
            parentGuid: "parent-1",
            eventTime: eventTime,
            attributes: ["email": "a@b.com"],
            pageInstanceGuid: "page-1",
            jwtToken: "jwt-1"
        )

        let event = EventMapper.event(from: request)

        XCTAssertEqual(event?.eventType, "capture_attributes")
        XCTAssertEqual(event?.instanceId, request.uuid)
        XCTAssertEqual(event?.timestamp, 1_700_000_000_000)
        XCTAssertEqual(event?.data?["attributes"], .object(["email": "a@b.com"]))
        XCTAssertEqual(event?.data?["token"], .string("jwt-1"))
    }
}
