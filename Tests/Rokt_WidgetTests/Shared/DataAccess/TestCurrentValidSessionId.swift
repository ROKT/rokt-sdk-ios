import XCTest
@testable import Rokt_Widget

/// Covers the session id put on the `rokt-session-id` header for diagnostics, timings and cart.
/// It must track the txn session's own token expiry, and must never mutate the store — that is
/// what separates it from `getSession()`, which clears an expired session as a side effect.
final class TestCurrentValidSessionId: XCTestCase {

    private final class InMemoryTxnStore: TxnSessionStore {
        private var values: [String: String] = [:]
        func string(forKey key: String) -> String? { values[key] }
        func setString(_ value: String, forKey key: String) { values[key] = value }
        func removeValue(forKey key: String) { values[key] = nil }
    }

    private var store: InMemoryTxnStore!
    private var implementation: RoktInternalImplementation!

    override func setUp() {
        super.setUp()
        store = InMemoryTxnStore()
        implementation = RoktInternalImplementation()
        implementation.txnSessionStore = store
        implementation.roktTagId = "tag-1"
    }

    override func tearDown() {
        store = nil
        implementation = nil
        super.tearDown()
    }

    private func seed(
        sessionId: String = "session-a",
        tagId: String = "tag-1",
        expiresInSeconds: TimeInterval = 1800
    ) {
        TxnSessionPersistence.seed(
            roktTagId: tagId,
            sessionId: sessionId,
            sessionToken: TxnSessionToken(
                token: "jwt",
                expiresAt: Int64(Date().addingTimeInterval(expiresInSeconds).timeIntervalSince1970 * 1000)
            ),
            store: store
        )
    }

    func test_returnsSessionId_whenTokenIsUnexpired() {
        seed()

        XCTAssertEqual(implementation.currentValidSessionId(), "session-a")
    }

    func test_returnsNil_whenTokenHasExpired() {
        seed(expiresInSeconds: -1)

        XCTAssertNil(implementation.currentValidSessionId())
    }

    /// Expiry is inclusive, matching `TxnSessionPersistence.isExpired`.
    func test_returnsNil_atTheExpiryBoundary() {
        let now = Date()
        TxnSessionPersistence.seed(
            roktTagId: "tag-1",
            sessionId: "session-a",
            sessionToken: TxnSessionToken(
                token: "jwt",
                expiresAt: Int64(now.timeIntervalSince1970 * 1000)
            ),
            store: store
        )

        XCTAssertNil(implementation.currentValidSessionId(clock: { now }))
    }

    func test_returnsNil_whenNoExpiryIsPersisted() {
        store.setString("tag-1", forKey: TxnSessionStoreKeys.tagId)
        store.setString("session-a", forKey: TxnSessionStoreKeys.sessionId)

        XCTAssertNil(implementation.currentValidSessionId())
    }

    /// Another account's persisted session must not leak into this one's diagnostics.
    func test_returnsNil_whenStoreIsBoundToADifferentTagId() {
        seed(tagId: "tag-2")

        XCTAssertNil(implementation.currentValidSessionId())
    }

    func test_returnsNil_whenSdkHasNoTagId() {
        seed()
        implementation.roktTagId = nil

        XCTAssertNil(implementation.currentValidSessionId())
    }

    func test_returnsNil_whenSessionIdIsEmpty() {
        seed(sessionId: "")

        XCTAssertNil(implementation.currentValidSessionId())
    }

    /// Building a request header must not clear the session, unlike `getSession()`.
    func test_doesNotMutateTheStore_whenTokenHasExpired() {
        seed(expiresInSeconds: -1)

        XCTAssertNil(implementation.currentValidSessionId())

        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.tagId), "tag-1")
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.sessionId), "session-a")
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.token), "jwt")
        XCTAssertNotNil(store.string(forKey: TxnSessionStoreKeys.expiresAt))
    }

    /// The reported bug: a session seen days ago is no longer stamped on new requests.
    func test_returnsNil_forASessionFromDaysAgo() {
        seed(expiresInSeconds: -6 * 24 * 60 * 60)

        XCTAssertNil(implementation.currentValidSessionId())
    }
}
