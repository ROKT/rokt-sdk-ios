import XCTest
@testable import Rokt_Widget

final class TestTxnEventWiring: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: MockTxnEventsHTTPClient!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
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

    /// A batch names the session that produced it. While that session is live it is sent as
    /// before; once it is not (cleared, or replaced by a later placement) the batch is replayed
    /// on its own session, so it neither rides the live token nor starts a session of its own.
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

    private func seedSession(_ sessionId: String, token: String, store: TxnSessionStore) {
        let expiryMs = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
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
