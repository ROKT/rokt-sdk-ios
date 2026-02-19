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
    var dateProvider: (() -> Date)!
    var currentDate: Date!
    var sessionManager: SessionManager!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        mockManagedSession = MockManagedSession()
        currentDate = Date()
        dateProvider = { self.currentDate }
        sessionManager = SessionManager(
            managedSessions: [mockManagedSession],
            userDefaults: userDefaults,
            dateProvider: dateProvider
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: #file)
        userDefaults = nil
        mockManagedSession = nil
        dateProvider = nil
        sessionManager = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_init_withDefaultParameters_initializesCorrectly() {
        let defaultSessionManager = SessionManager(managedSessions: [mockManagedSession])
        XCTAssertNotNil(defaultSessionManager)
        // We can't directly test the default UserDefaults or dateProvider without more complex setup or exposing them
        // So we primarily test that it doesn't crash and is non-nil
    }

    // MARK: - storedTagId Tests

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

        sessionManager.storedTagId = testTagId // Set same tagId again

        XCTAssertEqual(userDefaults.string(forKey: "rokt.sessionId"), "persistedSession")
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 2)
    }

    func test_storedTagId_set_whenDifferentFromOld_clearsSession() {
        let initialTagId = "initialTagId"
        let newTagId = "newTagId"

        sessionManager.storedTagId = initialTagId
        userDefaults.set("testSession", forKey: "rokt.sessionId")
        userDefaults.set(10, forKey: "rokt.sessionUsageCount")
        userDefaults.set(Date(), forKey: "rokt.lastExecuteCallDate")

        sessionManager.storedTagId = newTagId // Set different tagId

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 0)
        XCTAssertNil(userDefaults.object(forKey: "rokt.lastExecuteCallDate"))
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
        // Ensure session is initially nil (it is by default after setUp)
        userDefaults.set("testSession", forKey: "rokt.sessionId")

        sessionManager.storedTagId = "newTagId"

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    // MARK: - currentSessionDurationSeconds Tests

    func test_currentSessionDurationSeconds_get_returnsDefaultValueWhenNotSet() {
        let defaultDuration: TimeInterval = 30 * 60
        XCTAssertEqual(sessionManager.currentSessionDurationSeconds, defaultDuration)
    }

    func test_currentSessionDurationSeconds_setAndGet_returnsSetValue() {
        let customDuration: TimeInterval = 15 * 60
        sessionManager.currentSessionDurationSeconds = customDuration
        XCTAssertEqual(sessionManager.currentSessionDurationSeconds, customDuration)
    }

    func test_currentSessionDurationSeconds_persistsAcrossInstancesIfUserDefaultsIsTheSame() {
        let customDuration: TimeInterval = 10 * 60
        sessionManager.currentSessionDurationSeconds = customDuration

        let newSessionManager = SessionManager(
            managedSessions: [mockManagedSession],
            userDefaults: userDefaults, // Same UserDefaults instance
            dateProvider: dateProvider
        )
        XCTAssertEqual(newSessionManager.currentSessionDurationSeconds, customDuration)
    }

    // MARK: - sessionId (Getter) Tests

    func test_sessionId_get_whenNoSessionSet_returnsNil() {
        XCTAssertNil(sessionManager.getCurrentSessionIdWithoutExpiring())
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 0) // No session to invalidate
    }

    func test_sessionId_get_whenSessionValid_returnsSessionIdAndUpdatesLastCallDate() {
        let testSessionId = "validSession1"
        userDefaults.set(testSessionId, forKey: "rokt.sessionId")
        userDefaults
            .set(
                currentDate.addingTimeInterval(-100),
                forKey: "rokt.lastExecuteCallDate"
            ) // Set last call date in the past but within duration
        userDefaults.set(5, forKey: "rokt.sessionUsageCount") // Usage count is under threshold

        let initialDate = currentDate!
        currentDate = initialDate.addingTimeInterval(10) // Advance time slightly for the get call

        XCTAssertEqual(sessionManager.getCurrentSessionIdForLayoutRequest(), testSessionId)
        XCTAssertEqual(
            userDefaults.object(forKey: "rokt.lastExecuteCallDate") as? Date,
            currentDate
        ) // Check last call date updated
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 0)
    }

    func test_sessionId_get_whenSessionExpiredByTime_returnsNilAndClearsSession() {
        let testSessionId = "expiredSessionTime"
        userDefaults.set(testSessionId, forKey: "rokt.sessionId")
        let sessionDuration = sessionManager.currentSessionDurationSeconds
        userDefaults
            .set(
                currentDate.addingTimeInterval(-(sessionDuration + 1)),
                forKey: "rokt.lastExecuteCallDate"
            ) // Set last call date just outside duration
        userDefaults.set(5, forKey: "rokt.sessionUsageCount")

        XCTAssertNil(sessionManager.getCurrentSessionIdForLayoutRequest())
        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 0)
        XCTAssertNil(userDefaults.object(forKey: "rokt.lastExecuteCallDate"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    func test_sessionId_get_whenSessionExpiredByUsageCount_returnsNilAndClearsSession() {
        let testSessionId = "expiredSessionUsage"
        let maxUsage = 50
        userDefaults.set(testSessionId, forKey: "rokt.sessionId")
        userDefaults.set(currentDate.addingTimeInterval(-100), forKey: "rokt.lastExecuteCallDate") // Within time limit
        userDefaults.set(maxUsage + 1, forKey: "rokt.sessionUsageCount") // Exceeded usage count

        XCTAssertNil(sessionManager.getCurrentSessionIdForLayoutRequest())
        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 0)
        XCTAssertNil(userDefaults.object(forKey: "rokt.lastExecuteCallDate"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    func test_sessionId_get_whenLastExecuteCallDateNotSet_returnsSessionIdAndSetsLastCallDate() {
        let testSessionId = "validSessionNoDate"
        userDefaults.set(testSessionId, forKey: "rokt.sessionId")
        userDefaults.set(5, forKey: "rokt.sessionUsageCount")
        // lastExecuteCallDate is nil

        let initialDate = currentDate!

        XCTAssertEqual(sessionManager.getCurrentSessionIdForLayoutRequest(), testSessionId)
        XCTAssertEqual(userDefaults.object(forKey: "rokt.lastExecuteCallDate") as? Date, initialDate)
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 0)
    }

    func test_sessionId_get_usesCustomSessionDuration() {
        let testSessionId = "customDurationSession"
        let customDuration: TimeInterval = 10 * 60
        sessionManager.currentSessionDurationSeconds = customDuration
        sessionManager.updateSessionId(newSessionId: testSessionId)

//        userDefaults.set(testSessionId, forKey: "rokt.sessionId")
        userDefaults.set(5, forKey: "rokt.sessionUsageCount")
        // Set last call date just inside the *custom* duration
        userDefaults.set(currentDate.addingTimeInterval(-(customDuration - 10)), forKey: "rokt.lastExecuteCallDate")

        let initialDate = currentDate!
        currentDate = initialDate.addingTimeInterval(10)

        XCTAssertEqual(sessionManager.getCurrentSessionIdForLayoutRequest(), testSessionId) // Should still be valid
        XCTAssertEqual(userDefaults.object(forKey: "rokt.lastExecuteCallDate") as? Date, currentDate)
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)

        // Now advance time past the custom duration
        currentDate = initialDate.addingTimeInterval(customDuration + 100)

        XCTAssertNil(sessionManager.getCurrentSessionIdForLayoutRequest()) // Should now be invalid
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 2)
    }

    // MARK: - sessionId (Setter) Tests

    func test_sessionId_set_toNewValue_storesValue() {
        let newSessionId = "newSessionXYZ"
        sessionManager.updateSessionId(newSessionId: newSessionId)
        XCTAssertEqual(userDefaults.string(forKey: "rokt.sessionId"), newSessionId)
        XCTAssertEqual(
            mockManagedSession.sessionInvalidatedCallCount,
            1
        ) // Setting a new ID should invalidate the session unless the session ID was the same as stored
    }

    func test_updateSessionId_setsLastExecuteCallDate() {
        let testSessionId = "testSessionForDateUpdate"
        let expectedDate = currentDate! // Capture the date before calling the method

        sessionManager.updateSessionId(newSessionId: testSessionId)

        let storedDate = userDefaults.object(forKey: "rokt.lastExecuteCallDate") as? Date
        XCTAssertEqual(
            storedDate,
            expectedDate,
            "lastExecuteCallDate should be updated to the current date provided by dateProvider"
        )
    }

    func test_updateSessionId_withNilSessionId_clearsSessionAndSetsLastExecuteCallDate() {
        userDefaults.set("existingSession", forKey: "rokt.sessionId")
        userDefaults.set(5, forKey: "rokt.sessionUsageCount")
        // Set an old date to ensure it gets updated
        let oldDate = currentDate.addingTimeInterval(-1000)
        userDefaults.set(oldDate, forKey: "rokt.lastExecuteCallDate")

        let expectedDate = currentDate!

        sessionManager.updateSessionId(newSessionId: nil)

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"), "Session ID should be cleared")
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 0, "Session usage count should be cleared")
        // Even when clearing, we now expect lastExecuteCallDate to be set
        let storedDate = userDefaults.object(forKey: "rokt.lastExecuteCallDate") as? Date
        XCTAssertEqual(storedDate, expectedDate, "lastExecuteCallDate should be updated even when clearing session")
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1, "Managed session should be invalidated")
    }

    func test_sessionId_set_toNil_clearsSession() {
        userDefaults.set("existingSession", forKey: "rokt.sessionId")
        userDefaults.set(10, forKey: "rokt.sessionUsageCount")

        sessionManager.updateSessionId(newSessionId: nil)

        XCTAssertNil(userDefaults.string(forKey: "rokt.sessionId"))
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 0)
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    func test_updateSessionId_doesNotResetSessionStats_whenSessionIdIsSame() {
        // Set up initial session with some usage
        let existingSessionId = "existing-session-id"
        sessionManager.updateSessionId(newSessionId: existingSessionId)
        userDefaults.set(5, forKey: "rokt.sessionUsageCount")
        let initialDate = currentDate.addingTimeInterval(-100)
        userDefaults.set(initialDate, forKey: "rokt.lastExecuteCallDate")

        // Act - call updateSessionId with the same session ID
        sessionManager.updateSessionId(newSessionId: existingSessionId)

        // Assert - usage count should not be reset, last execute date should not change
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 5)
        XCTAssertEqual(userDefaults.object(forKey: "rokt.lastExecuteCallDate") as? Date, initialDate)
        XCTAssertEqual(userDefaults.string(forKey: "rokt.sessionId"), existingSessionId)
    }

    // MARK: - getCurrentSessionIdForExecute() Tests

    func test_getCurrentSessionIdForExecute_whenSessionValid_incrementsUsageCountAndReturnsSessionId() {
        let testSessionId = "execSessionValid"
        userDefaults.set(testSessionId, forKey: "rokt.sessionId")
        userDefaults.set(currentDate.addingTimeInterval(-100), forKey: "rokt.lastExecuteCallDate")
        userDefaults.set(5, forKey: "rokt.sessionUsageCount")

        let initialDate = currentDate!
        currentDate = initialDate.addingTimeInterval(10)

        let retrievedSessionId = sessionManager.getCurrentSessionIdForLayoutRequest()

        XCTAssertEqual(retrievedSessionId, testSessionId)
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 6) // Incremented
        XCTAssertEqual(
            userDefaults.object(forKey: "rokt.lastExecuteCallDate") as? Date,
            currentDate
        ) // Updated by sessionId getter
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 0)
    }

    func test_getCurrentSessionIdForExecute_whenSessionInvalid_incrementsUsageCountAndReturnsNil() {
        // Session is invalid (e.g., expired by time)
        userDefaults.set("execSessionInvalid", forKey: "rokt.sessionId")
        let sessionDuration = sessionManager.currentSessionDurationSeconds
        userDefaults.set(currentDate.addingTimeInterval(-(sessionDuration + 100)), forKey: "rokt.lastExecuteCallDate")
        userDefaults.set(5, forKey: "rokt.sessionUsageCount")

        let retrievedSessionId = sessionManager.getCurrentSessionIdForLayoutRequest()

        XCTAssertNil(retrievedSessionId)
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 0) // Cleared because session was invalid
        // Session was cleared, so lastExecuteCallDate is also nil
        XCTAssertNil(userDefaults.object(forKey: "rokt.lastExecuteCallDate"))
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }

    func test_getCurrentSessionIdForExecute_incrementsUsageCountCorrectly() {
        userDefaults.set("anySession", forKey: "rokt.sessionId")
        userDefaults.set(0, forKey: "rokt.sessionUsageCount")
        userDefaults.set(currentDate, forKey: "rokt.lastExecuteCallDate")

        _ = sessionManager.getCurrentSessionIdForLayoutRequest()
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 1)

        _ = sessionManager.getCurrentSessionIdForLayoutRequest()
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 2)

        // Ensure it still increments even if session becomes invalid due to usage
        userDefaults.set(50, forKey: "rokt.sessionUsageCount") // Max calls
        _ = sessionManager.getCurrentSessionIdForLayoutRequest() // This call makes it 51
        // The getter for sessionId will see usage as 51 (invalid) and clear it.
        // The getCurrentSessionIdForExecute increments *before* calling the sessionId getter.
        // So, the count *before* clearing would have been 51.
        // After clearing, it's 0.
        XCTAssertEqual(userDefaults.integer(forKey: "rokt.sessionUsageCount"), 0)
        XCTAssertEqual(mockManagedSession.sessionInvalidatedCallCount, 1)
    }
}
