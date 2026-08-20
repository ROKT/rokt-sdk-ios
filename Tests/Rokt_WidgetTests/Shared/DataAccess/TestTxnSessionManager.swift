import XCTest
@testable import Rokt_Widget

final class TestTxnSessionManager: XCTestCase {

    private var now: Date!
    private var manager: TxnSessionManager!

    override func setUp() {
        super.setUp()
        now = Date(timeIntervalSince1970: 1_000_000)
        manager = TxnSessionManager(clock: { self.now })
    }

    override func tearDown() {
        now = nil
        manager = nil
        super.tearDown()
    }

    private func token(_ value: String, expiresInSeconds seconds: TimeInterval) -> TxnSessionToken {
        let expiryMs = Int64(now.addingTimeInterval(seconds).timeIntervalSince1970 * 1000)
        return TxnSessionToken(token: value, expiresAt: expiryMs)
    }

    func test_initialState_hasNoSession() async {
        let sessionId = await manager.currentSessionId
        let header = await manager.authorizationHeader
        let isExpired = await manager.isExpired
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
        XCTAssertTrue(isExpired)
    }

    func test_update_storesSessionIdAndAuthorizationHeader() async {
        await manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))
        let sessionId = await manager.currentSessionId
        let header = await manager.authorizationHeader
        let isExpired = await manager.isExpired
        XCTAssertEqual(sessionId, "sid")
        XCTAssertEqual(header, "Bearer jwt")
        XCTAssertFalse(isExpired)
    }

    func test_expiredToken_dropsAuthorizationHeader_butRetainsSessionId() async {
        await manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)
        let header = await manager.authorizationHeader
        let isExpired = await manager.isExpired
        let sessionId = await manager.currentSessionId
        XCTAssertNil(header)
        XCTAssertTrue(isExpired)
        XCTAssertEqual(sessionId, "sid")
    }

    func test_expiryBoundary_isExpiredAtExactExpiry() async {
        await manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(60)
        let isExpired = await manager.isExpired
        let header = await manager.authorizationHeader
        XCTAssertTrue(isExpired)
        XCTAssertNil(header)
    }

    func test_tokenOnlyUpdate_keepsSessionId_andRefreshesToken() async {
        await manager.update(sessionId: "sid", sessionToken: token("old", expiresInSeconds: 10))
        await manager.update(sessionToken: token("new", expiresInSeconds: 1800))
        let sessionId = await manager.currentSessionId
        let header = await manager.authorizationHeader
        let isExpired = await manager.isExpired
        XCTAssertEqual(sessionId, "sid")
        XCTAssertEqual(header, "Bearer new")
        XCTAssertFalse(isExpired)
    }

    func test_refresh_extendsExpiryOnAnExpiredSession() async {
        await manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)
        let expiredBeforeRefresh = await manager.isExpired
        XCTAssertTrue(expiredBeforeRefresh)

        await manager.update(sessionToken: token("jwt2", expiresInSeconds: 1800))
        let isExpired = await manager.isExpired
        let header = await manager.authorizationHeader
        XCTAssertFalse(isExpired)
        XCTAssertEqual(header, "Bearer jwt2")
    }

    func test_clear_resetsAllState() async {
        await manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))
        await manager.clear()
        let sessionId = await manager.currentSessionId
        let header = await manager.authorizationHeader
        let isExpired = await manager.isExpired
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
        XCTAssertTrue(isExpired)
    }

    // MARK: - Persistence

    // Shared in-memory backing store so two managers see the same persisted state,
    // without touching the real Keychain during tests.
    private final class InMemoryStore: TxnSessionStore {
        private var values: [String: String] = [:]
        func string(forKey key: String) -> String? { values[key] }
        func setString(_ value: String, forKey key: String) { values[key] = value }
        func removeValue(forKey key: String) { values[key] = nil }
    }

    private func persistentManager(tagId: String, store: TxnSessionStore) -> TxnSessionManager {
        TxnSessionManager(roktTagId: tagId, store: store, clock: { self.now })
    }

    func test_persistence_restoresValidSessionForSameTagId() async {
        let store = InMemoryStore()
        await persistentManager(tagId: "tag-1", store: store)
            .update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", store: store)

        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertEqual(sessionId, "sid")
        XCTAssertEqual(header, "Bearer jwt")
        XCTAssertEqual(restored.boundTagId, "tag-1")
    }

    func test_persistence_clearsWhenTagIdDiffers() async {
        let store = InMemoryStore()
        await persistentManager(tagId: "tag-1", store: store)
            .update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        let other = persistentManager(tagId: "tag-2", store: store)

        let sessionId = await other.currentSessionId
        let header = await other.authorizationHeader
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
    }

    func test_persistence_switchingTagIdWipesPreviousAccountSession() async {
        let store = InMemoryStore()
        await persistentManager(tagId: "tag-1", store: store)
            .update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        _ = persistentManager(tagId: "tag-2", store: store)

        // Verify the data was wiped, not just skipped on restore.
        let backToTag1 = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await backToTag1.currentSessionId
        let header = await backToTag1.authorizationHeader
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
    }

    func test_persistence_dropsExpiredTokenOnLoad() async {
        let store = InMemoryStore()
        await persistentManager(tagId: "tag-1", store: store)
            .update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)

        let restored = persistentManager(tagId: "tag-1", store: store)

        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        let isExpired = await restored.isExpired
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
        XCTAssertTrue(isExpired)
    }

    func test_persistence_tokenOnlyRefreshAloneSurvivesReload() async {
        // Arrange: the first persisted state comes from a token-only refresh
        // (no prior full update wrote the tag-id binding).
        let store = InMemoryStore()
        let manager = persistentManager(tagId: "tag-1", store: store)

        // Act
        await manager.update(sessionToken: token("fresh", expiresInSeconds: 1800))
        let restored = persistentManager(tagId: "tag-1", store: store)

        // Assert
        let header = await restored.authorizationHeader
        XCTAssertEqual(header, "Bearer fresh")
    }

    func test_persistence_tokenOnlyRefreshDoesNotLoseSessionIdAcrossLoads() async {
        let store = InMemoryStore()
        let manager = persistentManager(tagId: "tag-1", store: store)
        await manager.update(sessionId: "sid", sessionToken: token("old", expiresInSeconds: 60))
        await manager.update(sessionToken: token("new", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", store: store)

        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertEqual(sessionId, "sid")
        XCTAssertEqual(header, "Bearer new")
    }

    func test_persistence_clearRemovesPersistedSession() async {
        let store = InMemoryStore()
        let manager = persistentManager(tagId: "tag-1", store: store)
        await manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        await manager.clear()
        let restored = persistentManager(tagId: "tag-1", store: store)

        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
    }

    func test_inMemoryManager_doesNotPersist() async {
        // The clock-only initializer is in-memory; nothing should leak to the store.
        let store = InMemoryStore()
        let inMemory = TxnSessionManager(clock: { self.now })
        await inMemory.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        let persistent = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await persistent.currentSessionId
        XCTAssertNil(sessionId)
    }

    // MARK: - TxnSessionPersistence (sync seed/read)

    func test_persistence_seed_isVisibleToTxnSessionManager() async {
        let store = InMemoryStore()
        TxnSessionPersistence.seed(
            roktTagId: "tag-1",
            sessionId: "seeded-sid",
            sessionToken: token("seeded-jwt", expiresInSeconds: 1800),
            store: store
        )

        let restored = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertEqual(sessionId, "seeded-sid")
        XCTAssertEqual(header, "Bearer seeded-jwt")
    }

    func test_persistence_readRaw_returnsSnapshot() {
        let store = InMemoryStore()
        TxnSessionPersistence.seed(
            roktTagId: "tag-1",
            sessionId: "sid",
            sessionToken: token("jwt", expiresInSeconds: 1800),
            store: store
        )

        let snapshot = TxnSessionPersistence.readRaw(store: store)

        XCTAssertEqual(snapshot.sessionId, "sid")
        XCTAssertEqual(snapshot.token, "jwt")
        XCTAssertNotNil(snapshot.expiresAt)
        XCTAssertTrue(TxnSessionPersistence.isBound(to: "tag-1", store: store))
    }

    func test_persistence_clearIfExpired_clearsStore() {
        let store = InMemoryStore()
        TxnSessionPersistence.seed(
            roktTagId: "tag-1",
            sessionId: "sid",
            sessionToken: token("jwt", expiresInSeconds: 60),
            store: store
        )
        store.setString("4", forKey: TxnSessionStoreKeys.epoch)
        now = now.addingTimeInterval(61)

        let snapshot = TxnSessionPersistence.readRaw(store: store)
        let cleared = TxnSessionPersistence.clearIfExpired(
            expiresAt: snapshot.expiresAt,
            store: store,
            clock: { self.now }
        )

        XCTAssertTrue(cleared)
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.token))
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.epoch), "4")
    }

    // MARK: - Epoch fence (a reset must survive an in-flight response)

    /// A response landing after a reset must not re-persist the departed customer's session.
    func test_update_afterAnotherInstanceCleared_doesNotResurrectSession() async {
        let store = InMemoryStore()
        let inFlight = persistentManager(tagId: "tag-1", store: store)
        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a", expiresInSeconds: 1800))

        TxnSessionManager.clearPersistedSession(store: store)

        // The in-flight request's response arrives after the reset.
        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a2", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertNil(sessionId, "A response landing after a reset must not restore the old session")
        XCTAssertNil(header)
    }

    /// Token-only rotation (the events response path) is fenced the same way.
    func test_updateSessionTokenOnly_afterClear_doesNotResurrectSession() async {
        let store = InMemoryStore()
        let inFlight = persistentManager(tagId: "tag-1", store: store)
        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a", expiresInSeconds: 1800))

        TxnSessionManager.clearPersistedSession(store: store)
        await inFlight.update(sessionToken: token("jwt-rotated", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", store: store)
        let header = await restored.authorizationHeader
        XCTAssertNil(header)
    }

    /// A manager built after the reset is current and must persist, or the fence would wedge.
    func test_managerCreatedAfterClear_persistsNormally() async {
        let store = InMemoryStore()
        TxnSessionManager.clearPersistedSession(store: store)

        let fresh = persistentManager(tagId: "tag-1", store: store)
        await fresh.update(sessionId: "sid-b", sessionToken: token("jwt-b", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await restored.currentSessionId
        XCTAssertEqual(sessionId, "sid-b")
    }

    /// An existing sender keeps the departing token, so events flushed just before the wipe
    /// stay attributed to that customer.
    func test_existingInstanceKeepsItsTokenAfterPersistedSessionIsCleared() async {
        let store = InMemoryStore()
        let inFlight = persistentManager(tagId: "tag-1", store: store)
        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a", expiresInSeconds: 1800))

        TxnSessionManager.clearPersistedSession(store: store)

        let header = await inFlight.authorizationHeader
        XCTAssertEqual(header, "Bearer jwt-a", "In-flight events must still send under the old token")
    }

    /// A stale instance's 401 says nothing about the live session, so it must not wipe it.
    func test_clearFromStaleInstance_doesNotWipeTheLiveSession() async {
        let store = InMemoryStore()
        let departing = persistentManager(tagId: "tag-1", store: store)
        await departing.update(sessionId: "sid-a", sessionToken: token("jwt-a", expiresInSeconds: 1800))

        TxnSessionManager.clearPersistedSession(store: store)

        // The next customer establishes their own session.
        let current = persistentManager(tagId: "tag-1", store: store)
        await current.update(sessionId: "sid-b", sessionToken: token("jwt-b", expiresInSeconds: 1800))

        // The departing customer's events request now 401s and calls clear().
        await departing.clear()

        let restored = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertEqual(sessionId, "sid-b", "A stale 401 must not tear down the live session")
        XCTAssertEqual(header, "Bearer jwt-b")
    }

    /// The fence must not disable legitimate 401 handling on the current session.
    func test_clearFromCurrentInstance_stillDropsTheSession() async {
        let store = InMemoryStore()
        let current = persistentManager(tagId: "tag-1", store: store)
        await current.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        await current.clear()

        let restored = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await restored.currentSessionId
        XCTAssertNil(sessionId)
    }

    func test_clearPersistedSession_removesEveryStoredKey() async {
        let store = InMemoryStore()
        let manager = persistentManager(tagId: "tag-1", store: store)
        await manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        TxnSessionManager.clearPersistedSession(store: store)

        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.tagId))
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.sessionId))
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.token))
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.expiresAt))
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.epoch), "1")
    }

    func test_persistence_clear_preservesEpoch() {
        let store = InMemoryStore()
        TxnSessionPersistence.seed(
            roktTagId: "tag-1",
            sessionId: "sid",
            sessionToken: token("jwt", expiresInSeconds: 1800),
            store: store
        )
        store.setString("9", forKey: TxnSessionStoreKeys.epoch)

        TxnSessionPersistence.clear(store: store)

        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.token))
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.epoch), "9")
    }

    func test_clearPersistedSession_isIdempotent() {
        let store = InMemoryStore()
        TxnSessionManager.clearPersistedSession(store: store)
        TxnSessionManager.clearPersistedSession(store: store)

        XCTAssertNil(store.string(forKey: "ROKT_TXN_SESSION_ID"))
    }

    /// Housekeeping clears must not bump the epoch, or a healthy in-flight writer is fenced.
    func test_restoreWithExpiredToken_doesNotFenceInFlightWriter() async {
        let store = InMemoryStore()
        let inFlight = persistentManager(tagId: "tag-1", store: store)
        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a", expiresInSeconds: 60))

        // Token lapses, then another service is constructed and housekeeping-clears the store.
        now = now.addingTimeInterval(61)
        _ = persistentManager(tagId: "tag-1", store: store)

        // The in-flight request now delivers a fresh token for the same session.
        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a2", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await restored.currentSessionId
        XCTAssertEqual(sessionId, "sid-a", "Housekeeping must not fence a healthy in-flight writer")
    }

    /// Tag-id mismatch on restore is housekeeping and must not bump the epoch.
    func test_restoreWithMismatchedTag_doesNotFenceInFlightWriter() async {
        let store = InMemoryStore()
        let inFlight = persistentManager(tagId: "tag-1", store: store)
        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a", expiresInSeconds: 1800))

        _ = persistentManager(tagId: "tag-2", store: store)

        await inFlight.update(sessionId: "sid-a", sessionToken: token("jwt-a2", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", store: store)
        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertEqual(sessionId, "sid-a", "Tag-mismatch housekeeping must not fence a healthy in-flight writer")
        XCTAssertEqual(header, "Bearer jwt-a2")
    }
}
