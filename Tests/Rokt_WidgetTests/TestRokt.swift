import XCTest

@testable import Rokt_Widget

class TestRokt: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_setEnvironment_valid_Stage() {
        Rokt.setEnvironment(environment: .Stage)
        XCTAssertEqual(config.environment, Environment.Stage)
        XCTAssertEqual(kBaseURL, Environment.Stage.baseURL)
    }

    func test_setEnvironment_valid_Prod() {
        Rokt.setEnvironment(environment: .Prod)
        XCTAssertEqual(config.environment, Environment.Prod)
        XCTAssertEqual(kBaseURL, Environment.Prod.baseURL)
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
