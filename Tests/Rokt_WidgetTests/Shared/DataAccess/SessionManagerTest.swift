import XCTest
@testable import Rokt_Widget

class MockManagedSession: ManagedSession {
    var sessionInvalidatedCallCount = 0
    func sessionInvalidated() {
        sessionInvalidatedCallCount += 1
    }
}

class SessionManagerTests: XCTestCase {

    var userDefaults: UserDefaults!
    var mockManagedSession: MockManagedSession!
    var sessionManager: SessionManager!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        mockManagedSession = MockManagedSession()
        sessionManager = SessionManager(
            managedSessions: [mockManagedSession],
            userDefaults: userDefaults
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: #file)
        userDefaults = nil
        mockManagedSession = nil
        sessionManager = nil
        super.tearDown()
    }

    func test_init_withDefaultParameters_initializesCorrectly() {
        let defaultSessionManager = SessionManager(managedSessions: [mockManagedSession])
        XCTAssertNotNil(defaultSessionManager)
    }

    func test_storedTagId_get_returnsNilWhenNotSet() {
        XCTAssertNil(sessionManager.storedTagId)
    }

    func test_storedTagId_setAndGet_returnsSetValue() {
        let testTagId = "testTagId123"
        sessionManager.storedTagId = testTagId
        XCTAssertEqual(sessionManager.storedTagId, testTagId)
    }

    func test_storedTagId_set_whenSameAsOld_doesNotClearSession() {
        let testTagId = "testTagId123"
        sessionManager.storedTagId = testTagId
        sessionManager.updateSessionId(newSessionId: "persistedSession")

        sessionManager.storedTagId = testTagId

        XCTAssertEqual(userDefaults.string(forKey: "rokt.sessionId"), "persistedSession")
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 2)
    }

    func test_storedTagId_set_whenDifferentFromOld_clearsSession() {
        let initialTagId = "initialTagId"
        let newTagId = "newTagId"

        sessionManager.storedTagId = initialTagId
        userDefaults.set("testSession", forKey: "rokt.sessionId")

        sessionManager.storedTagId = newTagId

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 2)
    }

    func test_storedTagId_set_toNil_clearsSessionIfPreviouslySet() {
        let initialTagId = "initialTagId"
        sessionManager.storedTagId = initialTagId
        userDefaults.set("testSession", forKey: "rokt.sessionId")

        sessionManager.storedTagId = nil

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 2)
    }

    func test_storedTagId_set_toValue_clearsSessionIfPreviouslyNil() {
        userDefaults.set("testSession", forKey: "rokt.sessionId")

        sessionManager.storedTagId = "newTagId"

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    func test_getCurrentSessionIdWithoutExpiring_whenNoSessionSet_returnsNil() {
        XCTAssertNil(sessionManager.getCurrentSessionIdWithoutExpiring())
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 0)
    }

    func test_getCurrentSessionIdWithoutExpiring_returnsStoredSessionId() {
        userDefaults.set("validSession1", forKey: "rokt.sessionId")
        XCTAssertEqual(sessionManager.getCurrentSessionIdWithoutExpiring(), "validSession1")
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 0)
    }

    func test_updateSessionId_toNewValue_storesValue() {
        let newSessionId = "newSessionXYZ"
        sessionManager.updateSessionId(newSessionId: newSessionId)
        XCTAssertEqual(userDefaults.string(forKey: "rokt.sessionId"), newSessionId)
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    func test_updateSessionId_withNilSessionId_clearsSession() {
        userDefaults.set("existingSession", forKey: "rokt.sessionId")

        sessionManager.updateSessionId(newSessionId: nil)

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    func test_updateSessionId_doesNotResetSession_whenSessionIdIsSame() {
        let existingSessionId = "existing-session-id"
        sessionManager.updateSessionId(newSessionId: existingSessionId)

        sessionManager.updateSessionId(newSessionId: existingSessionId)

        XCTAssertEqual(userDefaults.string(forKey: "rokt.sessionId"), existingSessionId)
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }
}
