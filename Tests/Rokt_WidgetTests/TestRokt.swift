import XCTest
import Foundation
@testable internal import RoktUXHelper

@testable import Rokt_Widget

class TestRokt: XCTestCase {

    override func setUp() {
        super.setUp()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_setCustomBaseURL_setsCustomEnvironment() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com")
    }

    func test_setCustomBaseURL_stripsPath() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com/api/v2")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com")
    }

    func test_setCustomBaseURL_stripsQueryAndFragment() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com/path?q=1#frag")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com")
    }

    func test_setCustomBaseURL_preservesPort() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com:8443")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com:8443")
    }

    func test_setCustomBaseURL_rejectsNonHTTPS() {
        let originalBaseURL = baseURL
        Rokt.setCustomBaseURL(URL(string: "http://rkt.example.com")!)
        XCTAssertEqual(baseURL, originalBaseURL)
    }

    func test_setCustomBaseURL_rejectsEmptyHost() {
        let originalBaseURL = baseURL
        Rokt.setCustomBaseURL(URL(string: "https://")!)
        XCTAssertEqual(baseURL, originalBaseURL)
    }

    func test_setEnvironment_valid_Stage() {
        Rokt.setEnvironment(environment: .Stage)
        XCTAssertEqual(config.environment, Environment.Stage)
        XCTAssertEqual(baseURL, Environment.Stage.baseURL)
    }

    func test_setEnvironment_valid_Prod() {
        Rokt.setEnvironment(environment: .Prod)
        XCTAssertEqual(config.environment, Environment.Prod)
        XCTAssertEqual(baseURL, Environment.Prod.baseURL)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

    func test_init_with_callback_success() {
        // Arrange
        let initComplete = XCTestExpectation(description: "Init complete")
        var initStatus = false

        // Act
        Rokt.globalEvents(onEvent: { roktEvent in
            if roktEvent is RoktEvent.InitComplete {
                initStatus = true
                initComplete.fulfill()
            }
        })
        Rokt.initWith(roktTagId: "12345")

        // Assert
        wait(for: [initComplete], timeout: 5)
        XCTAssertTrue(initStatus)
    }

    func test_mparticle_init_callback_success() {
        // Arrange
        let initComplete = XCTestExpectation(description: "Init complete")
        var initStatus = false

        let expectedSdkVersion = "1.2.3"
        let expectedKitVersion = "4.5.6"

        // Act
        Rokt.globalEvents(onEvent: { roktEvent in
            if roktEvent is RoktEvent.InitComplete {
                initStatus = true
                initComplete.fulfill()
            }
        })
        Rokt.initWith(
            roktTagId: "12345",
            mParticleSdkVersion: expectedSdkVersion,
            mParticleKitVersion: expectedKitVersion
        )

        // Assert
        XCTAssertEqual(NetworkingHelper.shared.mParticleKitDetails?.sdkVersion, expectedSdkVersion)
        XCTAssertEqual(NetworkingHelper.shared.mParticleKitDetails?.kitVersion, expectedKitVersion)

        wait(for: [initComplete], timeout: 5)
        XCTAssertTrue(initStatus)
    }

    func testProcessLayoutPageExecutePayload_noPlugins_sessionIdIsSaved() {
        // Arrange
        let roktInternalImplementation = RoktInternalImplementation()
        let sessionId = "test-session-id"
        let response = """
            {
              "sessionId": "\(sessionId)",
              "placementContext": {
                "roktTagId": "123",
                "pageInstanceGuid": "test-guid",
                "token": "test-token"
              },
              "placements": [],
              "plugins": [],
              "token": ""
            }
            """

        // Act
        _ = roktInternalImplementation.processLayoutPageExecutePayload(
            response, selectionId: "12345", viewName: "test", attributes: [:]
        )

        // Assert
        XCTAssertEqual(
            roktInternalImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
            sessionId
        )
    }

    // MARK: - setSessionId Tests

    func test_setSessionId_updatesSessionManager() {
        let roktInternalImplementation = RoktInternalImplementation()

        roktInternalImplementation.setSessionId(sessionId: "webview-session-id")

        XCTAssertEqual(
            roktInternalImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
            "webview-session-id"
        )
    }

    func test_setSessionId_ignoresEmptyString() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.setSessionId(sessionId: "existing-session-id")

        roktInternalImplementation.setSessionId(sessionId: "")

        // Empty string should be a no-op - original session should remain
        XCTAssertEqual(
            roktInternalImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
            "existing-session-id"
        )
    }

    // MARK: - getSessionId Tests

    func test_getSessionId_returnsNilWhenNoSession() {
        let roktInternalImplementation = RoktInternalImplementation()

        let sessionId = roktInternalImplementation.getSessionId()

        XCTAssertNil(sessionId)
    }

    func test_getSessionId_returnsSessionIdAfterSet() {
        let roktInternalImplementation = RoktInternalImplementation()
        let expectedSessionId = "test-session-123"
        roktInternalImplementation.setSessionId(sessionId: expectedSessionId)

        let sessionId = roktInternalImplementation.getSessionId()

        XCTAssertEqual(sessionId, expectedSessionId)
    }

    func test_buildContactAddress_mapsTransactionDataAddress() throws {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.attributes["email"] = "jane@example.com"

        let address = try JSONDecoder().decode(
            Address.self,
            from: Data(
                """
                {
                  "name": "Jane Doe",
                  "address1": "123 Test St",
                  "address2": null,
                  "city": "New York",
                  "state": "New York",
                  "stateCode": "NY",
                  "country": "United States",
                  "countryCode": "US",
                  "zip": "10001"
                }
                """.utf8
            )
        )

        let contactAddress = roktInternalImplementation.buildContactAddress(from: address)

        XCTAssertEqual(contactAddress?.name, "Jane Doe")
        XCTAssertEqual(contactAddress?.email, "jane@example.com")
        XCTAssertEqual(contactAddress?.addressLine1, "123 Test St")
        XCTAssertEqual(contactAddress?.city, "New York")
        XCTAssertEqual(contactAddress?.state, "NY")
        XCTAssertEqual(contactAddress?.postalCode, "10001")
        XCTAssertEqual(contactAddress?.country, "US")
    }

    func test_buildContactAddressFromAttributes_mapsLegacyShippingAttributes() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.attributes = [
            "firstname": "Jane",
            "lastname": "Doe",
            "email": "jane@example.com",
            "shippingaddress1": "456 Legacy Rd",
            "shippingcity": "Boston",
            "shippingstate": "MA",
            "shippingzipcode": "02110",
            "shippingcountry": "US"
        ]

        let contactAddress = roktInternalImplementation.buildContactAddressFromAttributes()

        XCTAssertEqual(contactAddress?.name, "Jane Doe")
        XCTAssertEqual(contactAddress?.email, "jane@example.com")
        XCTAssertEqual(contactAddress?.addressLine1, "456 Legacy Rd")
        XCTAssertEqual(contactAddress?.city, "Boston")
        XCTAssertEqual(contactAddress?.state, "MA")
        XCTAssertEqual(contactAddress?.postalCode, "02110")
        XCTAssertEqual(contactAddress?.country, "US")
    }

    func test_buildContactAddressFromAttributes_returnsNilWithoutAddressLine1() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.attributes = [
            "firstname": "Jane",
            "lastname": "Doe",
            "shippingcity": "Boston"
        ]

        XCTAssertNil(roktInternalImplementation.buildContactAddressFromAttributes())
    }

    // MARK: - Rokt Public API Tests

    func test_Rokt_setSessionId_updatesSession() {
        let expectedSessionId = "public-api-session-id"

        Rokt.setSessionId(sessionId: expectedSessionId)

        XCTAssertEqual(Rokt.getSessionId(), expectedSessionId)
    }

    func test_Rokt_getSessionId_returnsSessionId() {
        let expectedSessionId = "get-session-test-id"
        Rokt.setSessionId(sessionId: expectedSessionId)

        let sessionId = Rokt.getSessionId()

        XCTAssertEqual(sessionId, expectedSessionId)
    }

    func test_Rokt_setSessionId_ignoresEmptyString() {
        let originalSessionId = "original-session-id"
        Rokt.setSessionId(sessionId: originalSessionId)

        Rokt.setSessionId(sessionId: "")

        // Empty string should be a no-op - original session should remain
        XCTAssertEqual(Rokt.getSessionId(), originalSessionId)
    }
}
