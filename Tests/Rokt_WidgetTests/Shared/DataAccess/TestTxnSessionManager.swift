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

    // MARK: - Shared session (cross-integration handoff)

    func test_sharedSession_isNilWithoutASession() {
        XCTAssertNil(manager.sharedSession)
    }

    func test_sharedSession_exportsLiveSession() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))
        let shared = manager.sharedSession
        XCTAssertEqual(shared?.token, "jwt")
        XCTAssertFalse(manager.isExpired)
    }

    func test_sharedSession_isNilWhenExpired() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)
        XCTAssertNil(manager.sharedSession)
    }

    func test_seed_adoptsSessionSoItIsExportableAndAuthorized() {
        let shared = TxnSharedSession(
            token: "web-jwt",
            expiresAtDate: now.addingTimeInterval(1800)
        )
        manager.seed(sharedSession: shared)
        XCTAssertEqual(manager.authorizationHeader, "Bearer web-jwt")
        XCTAssertFalse(manager.isExpired)
    }

    func test_seed_roundTripsThroughExport() {
        let shared = TxnSharedSession(
            token: "web-jwt",
            expiresAtDate: now.addingTimeInterval(1800)
        )
        manager.seed(sharedSession: shared)
        XCTAssertEqual(manager.sharedSession, shared)
    }

    func test_seed_ignoresExpiredBundle() {
        let expired = TxnSharedSession(
            token: "web-jwt",
            expiresAtDate: now.addingTimeInterval(-1)
        )
        manager.seed(sharedSession: expired)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
    }

    func test_seed_expiredBundleDoesNotClobberLiveSession() {
        manager.update(sessionId: "native-sid", sessionToken: token("native-jwt", expiresInSeconds: 1800))
        let expired = TxnSharedSession(
            token: "web-jwt",
            expiresAtDate: now.addingTimeInterval(-1)
        )
        manager.seed(sharedSession: expired)
        XCTAssertEqual(manager.currentSessionId, "native-sid")
        XCTAssertEqual(manager.authorizationHeader, "Bearer native-jwt")
    }

    func test_seed_rejectsBundleAtExactExpiryBoundary() {
        // seed uses `clock() < expiresAtDate`; at clock() == expiresAtDate the
        // bundle must be rejected, matching isExpiredLocked's `>=` boundary.
        let atBoundary = TxnSharedSession(
            token: "web-jwt",
            expiresAtDate: now
        )
        manager.seed(sharedSession: atBoundary)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
    }

    func test_seed_atBoundaryDoesNotClobberLiveSession() {
        manager.update(sessionId: "native-sid", sessionToken: token("native-jwt", expiresInSeconds: 1800))
        let atBoundary = TxnSharedSession(
            token: "web-jwt",
            expiresAtDate: now
        )
        manager.seed(sharedSession: atBoundary)
        XCTAssertEqual(manager.currentSessionId, "native-sid")
        XCTAssertEqual(manager.authorizationHeader, "Bearer native-jwt")
    }

    func test_seed_rejectsBlankToken() {
        let blankToken = TxnSharedSession(
            token: "",
            expiresAtDate: now.addingTimeInterval(1800)
        )
        manager.seed(sharedSession: blankToken)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
    }

    func test_seed_blankCredentialDoesNotClobberLiveSession() {
        manager.update(sessionId: "native-sid", sessionToken: token("native-jwt", expiresInSeconds: 1800))
        let blankToken = TxnSharedSession(
            token: "",
            expiresAtDate: now.addingTimeInterval(1800)
        )
        manager.seed(sharedSession: blankToken)
        XCTAssertEqual(manager.currentSessionId, "native-sid")
        XCTAssertEqual(manager.authorizationHeader, "Bearer native-jwt")
    }
}
