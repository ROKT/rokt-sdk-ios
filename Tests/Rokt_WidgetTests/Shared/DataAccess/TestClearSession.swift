import XCTest
@testable import Rokt_Widget

/// Covers `Rokt.clearSession()` wiring: legacy session teardown, real-time event cleanup,
/// idempotency, and session-bound replay. The store itself is tested in `TestTxnSessionManager`.
final class TestClearSession: XCTestCase {

    private var userDefaults: UserDefaults!
    private var managedSession: MockManagedSession!
    private var implementation: RoktInternalImplementation!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        managedSession = MockManagedSession()
        implementation = RoktInternalImplementation(
            sessionManager: SessionManager(
                managedSessions: [managedSession],
                userDefaults: userDefaults
            )
        )
        RoktLogger.shared.sessionId = nil
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: #file)
        userDefaults = nil
        managedSession = nil
        implementation = nil
        RoktLogger.shared.sessionId = nil
        super.tearDown()
    }

    // MARK: - Reset scope

    /// The core invariant: no stored token afterwards, so the next offers call mints a session.
    func test_clearSession_dropsThePersistedTxnSession() async {
        let store = InMemoryTxnStore()
        implementation.txnSessionStore = store
        implementation.roktTagId = "tag-1"
        let manager = TxnSessionManager(roktTagId: "tag-1", store: store)
        await manager.update(
            sessionId: "session-a",
            sessionToken: TxnSessionToken(token: "jwt-a", expiresAt: farFutureExpiryMs)
        )

        implementation.clearSession()

        // Nothing left for the next placement to authenticate with.
        let next = TxnSessionManager(roktTagId: "tag-1", store: store)
        let sessionId = await next.currentSessionId
        let header = await next.authorizationHeader
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
    }

    /// `setSession` seeds the same keys `clearSession` wipes; a kiosk reset must drop the handoff.
    func test_clearSession_dropsSeededHandoffSession() async {
        let store = InMemoryTxnStore()
        implementation.txnSessionStore = store
        implementation.roktTagId = "tag-1"
        TxnSessionPersistence.seed(
            roktTagId: "tag-1",
            sessionId: "webview-sid",
            sessionToken: TxnSessionToken(token: "webview-jwt", expiresAt: farFutureExpiryMs),
            store: store
        )

        implementation.clearSession()

        let next = TxnSessionManager(roktTagId: "tag-1", store: store)
        let sessionId = await next.currentSessionId
        let header = await next.authorizationHeader
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.epoch), "1")
    }

    func test_clearSession_withNoTxnSession_leavesStoreEmpty() async {
        let store = InMemoryTxnStore()
        implementation.txnSessionStore = store
        implementation.roktTagId = "tag-1"

        implementation.clearSession()

        let next = TxnSessionManager(roktTagId: "tag-1", store: store)
        let header = await next.authorizationHeader
        XCTAssertNil(header)
    }

    func test_clearSession_dropsLegacySessionId() {
        implementation.setSessionId(sessionId: "session-from-webview")
        XCTAssertEqual(implementation.getSessionId(), "session-from-webview")

        implementation.clearSession()

        XCTAssertNil(implementation.getSessionId())
    }

    /// The next customer must not inherit the previous customer's real-time events.
    func test_clearSession_invalidatesManagedSessions() {
        implementation.setSessionId(sessionId: "session-a")
        let before = managedSession.sessionInvalidatedCallCount

        implementation.clearSession()

        XCTAssertEqual(managedSession.sessionInvalidatedCallCount, before + 1)
    }

    /// Not routed through `updateSessionId(nil)`, whose equality guard would skip the fan-out.
    func test_clearSession_withNoActiveSession_stillInvalidatesAndDoesNotCrash() {
        XCTAssertNil(implementation.getSessionId())

        implementation.clearSession()
        implementation.clearSession()

        XCTAssertNil(implementation.getSessionId())
        XCTAssertEqual(managedSession.sessionInvalidatedCallCount, 2)
    }

    // MARK: - Pending event replay

    func test_replayPendingTxnEvents_replaysEachBatchAgainstItsOwnSession() {
        let store = StubPendingStore(batches: [
            TxnPendingEventBatch(events: [event("a")], persistedAtMs: 0, sessionId: "session-a"),
            TxnPendingEventBatch(events: [event("b")], persistedAtMs: 0, sessionId: "session-b")
        ])
        let spy = replayCapturingImplementation(store: store)

        spy.replayPendingTxnEvents()

        XCTAssertEqual(spy.replayedSessionIds.sorted(), ["session-a", "session-b"])
    }

    /// Unbound batches cannot be attributed safely, so they are dropped rather than replayed.
    func test_replayPendingTxnEvents_dropsBatchesWithNoSessionBinding() {
        let store = StubPendingStore(batches: [
            TxnPendingEventBatch(events: [event("legacy")], persistedAtMs: 0, sessionId: nil),
            TxnPendingEventBatch(events: [event("bound")], persistedAtMs: 0, sessionId: "session-a")
        ])
        let spy = replayCapturingImplementation(store: store)

        spy.replayPendingTxnEvents()

        XCTAssertEqual(spy.replayedSessionIds, ["session-a"])
    }

    // MARK: - Helpers

    private var farFutureExpiryMs: Int64 {
        Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
    }

    /// Scratch store so assertions never touch `UserDefaults.standard`.
    private final class InMemoryTxnStore: TxnSessionStore {
        private var values: [String: String] = [:]
        func string(forKey key: String) -> String? { values[key] }
        func setString(_ value: String, forKey key: String) { values[key] = value }
        func removeValue(forKey key: String) { values[key] = nil }
    }

    private func event(_ id: String) -> TxnEvent {
        TxnEvent(eventType: "impression", instanceId: id, timestamp: 1_700_000_000_000, data: ["k": "v"])
    }

    private func replayCapturingImplementation(store: TxnPendingEventStoring) -> ReplayCapturingImplementation {
        let spy = ReplayCapturingImplementation(
            sessionManager: SessionManager(managedSessions: [], userDefaults: userDefaults)
        )
        spy.roktTagId = "tag-1"
        spy.txnPendingEventStore = store
        return spy
    }

    /// Records which session each batch is replayed against, without hitting the network.
    private final class ReplayCapturingImplementation: RoktInternalImplementation {
        private(set) var replayedSessionIds: [String] = []

        override func replayBatch(events: [TxnEvent], sessionId: String) {
            replayedSessionIds.append(sessionId)
        }
    }

    private final class StubPendingStore: TxnPendingEventStoring {
        private var batches: [TxnPendingEventBatch]
        init(batches: [TxnPendingEventBatch]) { self.batches = batches }

        func persist(events: [TxnEvent], sessionId: String?) {}

        func drainValid() -> [TxnPendingEventBatch] {
            defer { batches = [] }
            return batches
        }
    }
}
