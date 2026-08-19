import XCTest
@testable import Rokt_Widget

/// Covers `Rokt.clearSession()` at the implementation level: the self-service-terminal case
/// where one device serves a queue of unrelated customers and each transaction must land in
/// its own session. The session store itself is unit-tested in `TestTxnSessionManager`; this
/// covers the wiring — legacy session teardown, real-time event cleanup, idempotency, and the
/// session-bound replay of events that outlived their session.
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

    /// The invariant the whole feature rests on: after `clearSession()` there is no stored token,
    /// so the next offers request goes out unauthenticated and the gateway mints a new session.
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

    /// The next customer must not inherit real-time events captured for the previous one.
    func test_clearSession_invalidatesManagedSessions() {
        implementation.setSessionId(sessionId: "session-a")
        let before = managedSession.sessionInvalidatedCallCount

        implementation.clearSession()

        XCTAssertEqual(managedSession.sessionInvalidatedCallCount, before + 1)
    }

    /// Deliberately not routed through `updateSessionId(nil)`, whose equality guard would skip
    /// the managed-session fan-out when there is no id to replace.
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

    /// Batches written before session binding existed cannot be attributed safely: replaying
    /// one would file a previous customer's events against whoever is at the terminal now.
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

    /// Scratch store so the assertions never touch (or depend on) `UserDefaults.standard`.
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

    /// Records which session each pending batch is replayed against, without going to the network.
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
