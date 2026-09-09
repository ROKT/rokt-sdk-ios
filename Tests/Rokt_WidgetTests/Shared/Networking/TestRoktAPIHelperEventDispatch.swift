import XCTest
@testable import Rokt_Widget

/// Covers the buffered `RoktAPIHelper.sendEvent` leg (attribute capture on first positive
/// engagement): the queue hands events on per originating session, so an event queued by a
/// layout that outlived `clearSession()` cannot ride the next session.
final class TestRoktAPIHelperEventDispatch: XCTestCase {

    /// Records each dispatch without standing up the network stack.
    private final class DispatchRecordingImplementation: RoktInternalImplementation {
        private(set) var dispatches: [(events: [TxnEvent], originSessionId: String?)] = []

        override func dispatchTxnEvents(_ events: [TxnEvent], originSessionId: String?) {
            dispatches.append((events, originSessionId))
        }
    }

    private var userDefaults: UserDefaults!
    private var originalImpl: RoktInternalImplementation!
    private var impl: DispatchRecordingImplementation!

    override func setUp() {
        super.setUp()
        // Drain anything an earlier test left buffered before the shared implementation is swapped.
        EventQueue.flush()
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        originalImpl = Rokt.shared.roktImplementation
        impl = DispatchRecordingImplementation(
            sessionManager: SessionManager(managedSessions: [], userDefaults: userDefaults)
        )
        impl.roktTagId = "tag-1"
        impl.processedEvents = PlatformEventProcessor(stateBagManager: nil)
        Rokt.shared.roktImplementation = impl
    }

    override func tearDown() {
        EventQueue.flush()
        Rokt.shared.roktImplementation = originalImpl
        userDefaults.removePersistentDomain(forName: #file)
        userDefaults = nil
        impl = nil
        originalImpl = nil
        super.tearDown()
    }

    func test_sendEvent_flushesEachSessionsEventsUnderTheirOwnSessionId() {
        RoktAPIHelper.sendEvent(eventRequest: request(sessionId: "session-a", parentGuid: "a-1"))
        RoktAPIHelper.sendEvent(eventRequest: request(sessionId: "session-b", parentGuid: "b-1"))
        RoktAPIHelper.sendEvent(eventRequest: request(sessionId: "session-a", parentGuid: "a-2"))

        EventQueue.flush()

        XCTAssertEqual(impl.dispatches.map { $0.originSessionId }, ["session-a", "session-b"])
        XCTAssertEqual(impl.dispatches.map { $0.events.count }, [2, 1])
    }

    func test_sendEvent_singleSession_dispatchesOnceUnderThatSession() {
        RoktAPIHelper.sendEvent(eventRequest: request(sessionId: "session-a", parentGuid: "a-1"))
        RoktAPIHelper.sendEvent(eventRequest: request(sessionId: "session-a", parentGuid: "a-2"))

        EventQueue.flush()

        XCTAssertEqual(impl.dispatches.map { $0.originSessionId }, ["session-a"])
        XCTAssertEqual(impl.dispatches.first?.events.count, 2)
    }

    private func request(sessionId: String, parentGuid: String) -> EventRequest {
        EventRequest(
            sessionId: sessionId,
            eventType: .CaptureAttributes,
            parentGuid: parentGuid,
            attributes: ["tier": "gold"],
            pageInstanceGuid: "page-1",
            jwtToken: "offer-token"
        )
    }
}
