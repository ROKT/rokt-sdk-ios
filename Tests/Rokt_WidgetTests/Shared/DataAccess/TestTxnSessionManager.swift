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

    func test_initialState_hasNoSession() {
        XCTAssertNil(manager.currentSessionId)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
    }

    func test_update_storesSessionIdAndAuthorizationHeader() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))
        XCTAssertEqual(manager.currentSessionId, "sid")
        XCTAssertEqual(manager.authorizationHeader, "Bearer jwt")
        XCTAssertFalse(manager.isExpired)
    }

    func test_expiredToken_dropsAuthorizationHeader_butRetainsSessionId() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
        XCTAssertEqual(manager.currentSessionId, "sid")
    }

    func test_expiryBoundary_isExpiredAtExactExpiry() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(60)
        XCTAssertTrue(manager.isExpired)
        XCTAssertNil(manager.authorizationHeader)
    }

    func test_tokenOnlyUpdate_keepsSessionId_andRefreshesToken() {
        manager.update(sessionId: "sid", sessionToken: token("old", expiresInSeconds: 10))
        manager.update(sessionToken: token("new", expiresInSeconds: 1800))
        XCTAssertEqual(manager.currentSessionId, "sid")
        XCTAssertEqual(manager.authorizationHeader, "Bearer new")
        XCTAssertFalse(manager.isExpired)
    }

    func test_refresh_extendsExpiryOnAnExpiredSession() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)
        XCTAssertTrue(manager.isExpired)

        manager.update(sessionToken: token("jwt2", expiresInSeconds: 1800))
        XCTAssertFalse(manager.isExpired)
        XCTAssertEqual(manager.authorizationHeader, "Bearer jwt2")
    }

    func test_clear_resetsAllState() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))
        manager.clear()
        XCTAssertNil(manager.currentSessionId)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
    }

    // MARK: - Persistence

    private func makeDefaults() -> UserDefaults {
        let suite = "txn.session.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func persistentManager(tagId: String, defaults: UserDefaults) -> TxnSessionManager {
        TxnSessionManager(roktTagId: tagId, userDefaults: defaults, clock: { self.now })
    }

    func test_persistence_restoresValidSessionForSameTagId() {
        let defaults = makeDefaults()
        persistentManager(tagId: "tag-1", defaults: defaults)
            .update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", defaults: defaults)

        XCTAssertEqual(restored.currentSessionId, "sid")
        XCTAssertEqual(restored.authorizationHeader, "Bearer jwt")
        XCTAssertEqual(restored.boundTagId, "tag-1")
    }

    func test_persistence_clearsWhenTagIdDiffers() {
        let defaults = makeDefaults()
        persistentManager(tagId: "tag-1", defaults: defaults)
            .update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        let other = persistentManager(tagId: "tag-2", defaults: defaults)

        XCTAssertNil(other.currentSessionId)
        XCTAssertNil(other.authorizationHeader)
    }

    func test_persistence_dropsExpiredTokenOnLoad() {
        let defaults = makeDefaults()
        persistentManager(tagId: "tag-1", defaults: defaults)
            .update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)

        let restored = persistentManager(tagId: "tag-1", defaults: defaults)

        XCTAssertNil(restored.currentSessionId)
        XCTAssertNil(restored.authorizationHeader)
        XCTAssertTrue(restored.isExpired)
    }

    func test_persistence_tokenOnlyRefreshDoesNotLoseSessionIdAcrossLoads() {
        let defaults = makeDefaults()
        let manager = persistentManager(tagId: "tag-1", defaults: defaults)
        manager.update(sessionId: "sid", sessionToken: token("old", expiresInSeconds: 60))
        manager.update(sessionToken: token("new", expiresInSeconds: 1800))

        let restored = persistentManager(tagId: "tag-1", defaults: defaults)

        XCTAssertEqual(restored.currentSessionId, "sid")
        XCTAssertEqual(restored.authorizationHeader, "Bearer new")
    }

    func test_persistence_clearRemovesPersistedSession() {
        let defaults = makeDefaults()
        let manager = persistentManager(tagId: "tag-1", defaults: defaults)
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        manager.clear()
        let restored = persistentManager(tagId: "tag-1", defaults: defaults)

        XCTAssertNil(restored.currentSessionId)
        XCTAssertNil(restored.authorizationHeader)
    }

    func test_inMemoryManager_doesNotPersist() {
        // The clock-only initializer is in-memory; nothing should leak to UserDefaults.
        let defaults = makeDefaults()
        let inMemory = TxnSessionManager(clock: { self.now })
        inMemory.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))

        let persistent = persistentManager(tagId: "tag-1", defaults: defaults)
        XCTAssertNil(persistent.currentSessionId)
    }
}
