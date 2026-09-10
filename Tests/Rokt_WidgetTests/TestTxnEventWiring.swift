import XCTest
@testable import Rokt_Widget

final class TestTxnEventWiring: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: MockTxnEventsHTTPClient!
    private var userDefaults: UserDefaults!
    // The clock a test-built session manager reads, so a test decides when its token expires.
    private var now: Date!

    override func setUp() {
        super.setUp()
        now = Date(timeIntervalSince1970: 1_000_000)
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        // A scratch legacy session so `clearSession()` never touches `UserDefaults.standard`.
        impl = RoktInternalImplementation(
            sessionManager: SessionManager(managedSessions: [], userDefaults: userDefaults)
        )
        stub = MockTxnEventsHTTPClient()
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: #file)
        userDefaults = nil
        impl = nil
        stub = nil
        now = nil
        super.tearDown()
    }

    private func injectService() {
        impl.makeTxnEventServiceOverride = { [stub] tagId in
            TxnEventService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                sessionManager: TxnSessionManager(),
                httpClient: stub!,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
    }

    private func sampleEvent() -> TxnEvent {
        TxnEvent(eventType: "impression", instanceId: "instance-1", timestamp: 1_700_000_000_000, data: ["k": "v"])
    }

    func test_dispatch_withTagId_sendsThroughService() {
        injectService()
        impl.roktTagId = "tag-1"

        impl.dispatchTxnEvents([sampleEvent()])

        waitUntil { self.stub.callCount == 1 }
    }

    func test_dispatch_withoutTagId_doesNotSend() {
        injectService()

        impl.dispatchTxnEvents([sampleEvent()])

        settle()
        XCTAssertEqual(stub.callCount, 0)
    }

    func test_dispatch_withEmptyEvents_doesNotSend() {
        injectService()
        impl.roktTagId = "tag-1"

        impl.dispatchTxnEvents([])

        settle()
        XCTAssertEqual(stub.callCount, 0)
    }

    // MARK: - Session binding

    /// A batch names the session that produced it. While that session is the stored one and its
    /// token is unexpired the batch is sent with that bearer; once it is not (cleared, replaced by
    /// a later placement, or its token expired) the batch is stamped with its own session id and
    /// sent without Authorization, so it neither rides the live token nor starts a session of its
    /// own. Red if the origin route stamps while the live bearer is available.
    func test_dispatch_originIsLiveSession_sendsWithLiveBearer() {
        let store = InMemoryTxnStore()
        injectPersistedSessionService(store: store)
        seedSession("session-a", token: "jwt-a", store: store)

        impl.dispatchTxnEvents([sampleEvent()], originSessionId: "session-a")

        waitUntil { self.stub.callCount == 1 }
        XCTAssertEqual(stub.capturedHeaders.first?["Authorization"], "Bearer jwt-a")
        XCTAssertEqual(bodySessionIds(), [nil])
    }

    /// Nothing stored after a reset: the batch must not go out unbound, and the token the
    /// response returns must not be persisted for the next placement to inherit.
    func test_dispatch_afterClearSession_emptyStore_replaysOnOriginAndPersistsNoToken() {
        let store = InMemoryTxnStore()
        injectPersistedSessionService(store: store)
        seedSession("session-a", token: "jwt-a", store: store)
        impl.clearSession()
        stub.results = [.success(status: 200, data: tokenResponse("minted-jwt"))]

        impl.dispatchTxnEvents([sampleEvent()], originSessionId: "session-a")

        waitUntil { self.stub.callCount == 1 }
        settle()
        XCTAssertNil(stub.capturedHeaders.first?["Authorization"])
        XCTAssertEqual(bodySessionIds(), ["session-a"])
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.token))
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.sessionId))
    }

    /// A later placement has already started another session: the batch stays on its own
    /// session and leaves the stored one untouched.
    func test_dispatch_afterClearSession_newSessionStored_staysOnOriginWithoutNewBearer() {
        let store = InMemoryTxnStore()
        injectPersistedSessionService(store: store)
        seedSession("session-a", token: "jwt-a", store: store)
        impl.clearSession()
        seedSession("session-b", token: "jwt-b", store: store)
        stub.results = [.success(status: 200, data: tokenResponse("rotated-jwt"))]

        impl.dispatchTxnEvents([sampleEvent()], originSessionId: "session-a")

        waitUntil { self.stub.callCount == 1 }
        settle()
        XCTAssertNil(stub.capturedHeaders.first?["Authorization"])
        XCTAssertEqual(bodySessionIds(), ["session-a"])
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.token), "jwt-b")
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.sessionId), "session-b")
    }

    /// No origin: the batch follows the live session, as before.
    func test_dispatch_withoutOrigin_followsLiveSession() {
        let store = InMemoryTxnStore()
        injectPersistedSessionService(store: store)
        seedSession("session-b", token: "jwt-b", store: store)

        impl.dispatchTxnEvents([sampleEvent()])

        waitUntil { self.stub.callCount == 1 }
        XCTAssertEqual(stub.capturedHeaders.first?["Authorization"], "Bearer jwt-b")
        XCTAssertEqual(bodySessionIds(), [nil])
    }

    /// A blank origin cannot be bound; the batch follows the live session.
    func test_dispatch_withEmptyOrigin_followsLiveSession() {
        let store = InMemoryTxnStore()
        injectPersistedSessionService(store: store)
        seedSession("session-b", token: "jwt-b", store: store)

        impl.dispatchTxnEvents([sampleEvent()], originSessionId: "")

        waitUntil { self.stub.callCount == 1 }
        XCTAssertEqual(stub.capturedHeaders.first?["Authorization"], "Bearer jwt-b")
        XCTAssertEqual(bodySessionIds(), [nil])
    }

    // MARK: - Session binding when the token has expired

    /// The origin is still the stored session, but its token expired before the batch was sent. The
    /// session id alone would choose the live path, whose bearer is then nil, and the batch would
    /// leave with neither binding for the server to mint a session around. It must go out stamped,
    /// and the token the response returns must not be adopted. Red when the route is chosen from
    /// the session id and the bearer is read separately, and red when the origin route falls back
    /// to the live send on a missing bearer.
    func test_dispatch_originIsStoredSession_tokenExpired_stampsOriginWithoutAuthorization() {
        let store = InMemoryTxnStore()
        seedSession("session-a", token: "jwt-a", store: store, expiresAt: now.addingTimeInterval(60))
        injectService(on: TxnSessionManager(roktTagId: "tag-1", store: store, clock: { self.now }))
        now = now.addingTimeInterval(61)
        stub.results = [.success(status: 200, data: tokenResponse("minted-jwt"))]

        impl.dispatchTxnEvents([sampleEvent(), sampleEvent()], originSessionId: "session-a")

        waitUntil { self.stub.callCount == 1 }
        settle()
        XCTAssertNil(stub.capturedHeaders.first?["Authorization"])
        XCTAssertEqual(bodySessionIds(), ["session-a", "session-a"])
        XCTAssertEqual(store.string(forKey: TxnSessionStoreKeys.token), "jwt-a")
    }

    /// No origin and an expired token: the batch follows the live session as before, with neither
    /// a bearer nor a stamp, and the server mints a fresh session for it. Red if the live route ever
    /// stamps, or if a dispatch without an origin is routed through the origin-bound send.
    func test_dispatch_withoutOrigin_tokenExpired_sendsUnboundAsBefore() {
        let store = InMemoryTxnStore()
        seedSession("session-b", token: "jwt-b", store: store, expiresAt: now.addingTimeInterval(60))
        injectService(on: TxnSessionManager(roktTagId: "tag-1", store: store, clock: { self.now }))
        now = now.addingTimeInterval(61)

        impl.dispatchTxnEvents([sampleEvent()])

        waitUntil { self.stub.callCount == 1 }
        XCTAssertNil(stub.capturedHeaders.first?["Authorization"])
        XCTAssertEqual(bodySessionIds(), [nil])
    }

    // MARK: - Helpers

    /// Scratch store so assertions never touch `UserDefaults.standard`.
    private final class InMemoryTxnStore: TxnSessionStore {
        private var values: [String: String] = [:]
        func string(forKey key: String) -> String? { values[key] }
        func setString(_ value: String, forKey key: String) { values[key] = value }
        func removeValue(forKey key: String) { values[key] = nil }
    }

    /// Wires the events service to a persisted store the way production does, so every dispatch
    /// rehydrates whichever session is live at send time.
    private func injectPersistedSessionService(store: TxnSessionStore) {
        impl.txnSessionStore = store
        impl.roktTagId = "tag-1"
        impl.makeTxnEventServiceOverride = { [stub] tagId in
            TxnEventService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                sessionManager: TxnSessionManager(roktTagId: tagId, store: store),
                httpClient: stub!,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
    }

    /// One manager, built by the test and shared by every dispatch, so the test controls when its
    /// token expires. Production builds a manager per dispatch; this stands in for one that outlives
    /// its token, as a manager sending several batches in sequence does.
    private func injectService(on manager: TxnSessionManager) {
        impl.roktTagId = "tag-1"
        impl.makeTxnEventServiceOverride = { [stub] tagId in
            TxnEventService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                sessionManager: manager,
                httpClient: stub!,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
    }

    /// Seeds a session that expires at `expiresAt`, half an hour from now when not given.
    private func seedSession(_ sessionId: String, token: String, store: TxnSessionStore, expiresAt: Date? = nil) {
        let expiry = expiresAt ?? Date().addingTimeInterval(1800)
        let expiryMs = Int64(expiry.timeIntervalSince1970 * 1000)
        TxnSessionPersistence.seed(
            roktTagId: "tag-1",
            sessionId: sessionId,
            sessionToken: TxnSessionToken(token: token, expiresAt: expiryMs),
            store: store
        )
    }

    private func tokenResponse(_ token: String) -> Data {
        let expiryMs = Int64(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)
        return Data(
            """
            {
              "session_token": { "token": "\(token)", "expires_at": \(expiryMs) },
              "event_ids": ["event-1"]
            }
            """.utf8
        )
    }

    /// The `session_id` of every event in the first request body; `nil` where none was stamped.
    private func bodySessionIds() -> [String?] {
        let events = stub.capturedBodies.first?["events"] as? [[String: Any]] ?? []
        return events.map { $0["session_id"] as? String }
    }

    /// Lets the response handling that follows a captured request run to completion.
    private func settle(_ interval: TimeInterval = 0.3) {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
    }
}
