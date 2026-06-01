import XCTest
@testable import RoktUXHelper

class TestEventRequest: XCTestCase {

    func test_event_with_correct_session_id_and_parenet_guid_and_event_type_and_jwt_token() {
        let eventRequest = RoktEventRequest(
            sessionId: "sessionID",
            eventType: RoktUXEventType.SignalImpression,
            parentGuid: "parentGuid",
            pageInstanceGuid: "page",
            jwtToken: "jwt-token"
        )
        
        XCTAssertEqual(eventRequest.sessionId, "sessionID")
        XCTAssertEqual(eventRequest.eventType, RoktUXEventType.SignalImpression)
        XCTAssertEqual(eventRequest.parentGuid, "parentGuid")
        XCTAssertEqual(eventRequest.pageInstanceGuid, "page")
        XCTAssertEqual(eventRequest.jwtToken, "jwt-token")
    }
    
    func test_event_withoutJWTToken_returnsNil() {
        let eventRequest = RoktEventRequest(
            sessionId: "sessionID",
            eventType: RoktUXEventType.SignalImpression,
            parentGuid: "parentGuid",
            pageInstanceGuid: "page",
            jwtToken: "jwt-token"
        )

        XCTAssertEqual(eventRequest.sessionId, "sessionID")
        XCTAssertEqual(eventRequest.eventType, RoktUXEventType.SignalImpression)
        XCTAssertEqual(eventRequest.parentGuid, "parentGuid")
        XCTAssertEqual(eventRequest.pageInstanceGuid, "page")
    }

    func test_event_create_date() {
        let eventTime = Date()
        let eventRequest = RoktEventRequest(
            sessionId: "",
            eventType: RoktUXEventType.SignalImpression,
            parentGuid: "",
            eventTime: eventTime,
            jwtToken: "jwt"
        )

        XCTAssertNotNil(eventRequest.metadata)
        XCTAssertNotNil(eventRequest.metadata[0])
        XCTAssertEqual(eventRequest.metadata[0].name, BE_CLIENT_TIME_STAMP)
        XCTAssertEqual(eventRequest.metadata[0].value, EventDateFormatter.getDateString(eventTime))
        XCTAssertNotNil(eventRequest.metadata[0].value)
    }

    func test_event_create_capture_method() {
        let eventRequest = RoktEventRequest(
            sessionId: "",
            eventType: RoktUXEventType.SignalImpression,
            parentGuid: "",
            jwtToken: "jwt"
        )

        XCTAssertNotNil(eventRequest.metadata[1])
        XCTAssertEqual(eventRequest.metadata[1].name, BE_CAPTURE_METHOD)
        XCTAssertEqual(eventRequest.metadata[1].value, kClientProvided)
    }

    func test_event_create_currect_time_stamp() {
        let eventRequest = RoktEventRequest(
            sessionId: "",
            eventType: RoktUXEventType.SignalImpression,
            parentGuid: "",
            jwtToken: "jwt"
        )
        let timeStampRegex = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T([0-9]{2}:){2}[0-9]{2}.[0-9]{3}Z$"

        XCTAssertNotNil(eventRequest.metadata[0].value)
        XCTAssertTrue(matchesRegex(eventRequest.metadata[0].value, regex: timeStampRegex))
    }

    func test_event_get_params() {
        let eventRequest = RoktEventRequest(
            sessionId: "sessionID",
            eventType: RoktUXEventType.SignalImpression,
            parentGuid: "parentGuid",
            pageInstanceGuid: "page",
            jwtToken: "jwt"
        )

        let params = eventRequest.getParams

        XCTAssertEqual(params[BE_SESSION_ID_KEY] as! String, "sessionID")
        XCTAssertEqual(params[BE_PARENT_GUID_KEY] as! String, "parentGuid")
        XCTAssertEqual(params[BE_PAGE_INSTANCE_GUID_KEY] as! String, "page")
        XCTAssertEqual(params[BE_EVENT_TYPE_KEY] as! String, RoktUXEventType.SignalImpression.rawValue)
        XCTAssertNotNil(params[BE_EVENT_DATA_KEY])
        XCTAssertNotNil(params[BE_INSTANCE_GUID])
        XCTAssertNotNil(params[BE_METADATA_KEY])
    }

    func test_event_get_params_includes_object_data_when_present() {
        let eventRequest = RoktEventRequest(
            sessionId: "sessionID",
            eventType: RoktUXEventType.SignalUserInteraction,
            parentGuid: "parentGuid",
            eventData: ["action": "click"],
            objectData: ["context": "catalog"],
            pageInstanceGuid: "page",
            jwtToken: "jwt"
        )

        let params = eventRequest.getParams

        XCTAssertEqual(params[BE_OBJECT_DATA_KEY] as? [String: String], ["context": "catalog"])
    }

    func test_event_get_params_omits_empty_object_data() {
        let eventRequest = RoktEventRequest(
            sessionId: "sessionID",
            eventType: RoktUXEventType.SignalUserInteraction,
            parentGuid: "parentGuid",
            eventData: ["action": "click"],
            objectData: [:],
            pageInstanceGuid: "page",
            jwtToken: "jwt"
        )

        let params = eventRequest.getParams

        XCTAssertNil(params[BE_OBJECT_DATA_KEY])
    }

    func test_event_request_round_trips_object_data() throws {
        let eventRequest = RoktEventRequest(
            sessionId: "sessionID",
            eventType: RoktUXEventType.SignalUserInteraction,
            parentGuid: "parentGuid",
            eventData: ["action": "click"],
            objectData: ["context": "catalog", "action": "select"],
            pageInstanceGuid: "page",
            jwtToken: "jwt"
        )

        let encoded = try JSONEncoder().encode(eventRequest)
        let decoded = try JSONDecoder().decode(RoktEventRequest.self, from: encoded)

        XCTAssertEqual(decoded.objectData, ["context": "catalog", "action": "select"])
    }

    func matchesRegex(_ text: String, regex: String) -> Bool {
        return text.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
