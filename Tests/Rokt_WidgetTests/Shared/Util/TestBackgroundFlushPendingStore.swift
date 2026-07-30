import XCTest
import UIKit
@testable import Rokt_Widget
internal import RoktUXHelper

/// Composed coverage for the #250+#251 intersection: background lifecycle flush drains the
/// debounce buffer into a send that fails while backgrounded, which must rewrite the pending
/// event store so a later drain (next init) can replay.
final class TestBackgroundFlushPendingStore: XCTestCase {

    private var fileURL: URL!
    private var httpClient: MockTxnEventsHTTPClient!
    private var sessionManager: TxnSessionManager!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("txn_pending_bg_\(UUID().uuidString).json")
        httpClient = MockTxnEventsHTTPClient()
        sessionManager = TxnSessionManager(clock: { Date(timeIntervalSince1970: 1_000_000) })
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        fileURL = nil
        httpClient = nil
        sessionManager = nil
        super.tearDown()
    }

    private func makeService(pendingStore: TxnPendingEventStoring) -> TxnEventService {
        TxnEventService(
            environment: .Prod,
            accountId: "account-1",
            sdkVersion: "5.2.2",
            sessionManager: sessionManager,
            httpClient: httpClient,
            maxRetries: 3,
            baseBackoff: 0,
            pendingStore: pendingStore,
            sleep: { _ in }
        )
    }

    private func sampleEventRequest() -> EventRequest {
        EventRequest(sessionId: "session", eventType: .CaptureAttributes, parentGuid: "parent-1", jwtToken: "jwt")
    }

    func test_didEnterBackground_flush_failedSend_persistsBatchForLaterDrain() async {
        let pendingStore = TxnPendingEventStore(fileURL: fileURL, clock: { 1_700_000_000_000 })
        let offline = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        httpClient.results = [.transport(offline)]

        let service = makeService(pendingStore: pendingStore)
        let sendFinished = expectation(description: "background send finished")

        let center = NotificationCenter()
        let observer = EventFlushLifecycleObserver(notificationCenter: center) {
            EventQueue.flush()
        }

        // Partner fulfillment attributes land in the debounce buffer (only txn path that uses EventQueue).
        EventQueue.call(event: sampleEventRequest()) { events in
            let txnEvents = events.compactMap { TxnEventMapper.event(from: $0) }
            Task {
                try? await service.send(events: txnEvents)
                sendFinished.fulfill()
            }
        }

        // Background before the 0.25s debounce fires — #250 flush path.
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        await fulfillment(of: [sendFinished], timeout: 2)
        withExtendedLifetime(observer) {}

        // #251: the failed background send rewrote the pending store for next-init replay.
        let drained = pendingStore.drainValid()
        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.first?.eventType, "capture_attributes")
        XCTAssertTrue(pendingStore.drainValid().isEmpty)
    }

    func test_failedBackgroundPersists_thenSecondProcessDrainReplaysShape() async {
        // First "process": persist via exhausted recoverable failure (store rewrite from background).
        let pendingStore = TxnPendingEventStore(fileURL: fileURL, clock: { 1_700_000_000_000 })
        httpClient.results = [.status(503)]
        do {
            try await makeService(pendingStore: pendingStore).send(events: [
                TxnEvent(
                    eventType: "capture_attributes",
                    instanceId: "instance-bg",
                    timestamp: 1_700_000_000_000,
                    data: ["confirmationref": "ORD-E2E"]
                )
            ])
            XCTFail("Expected recoverable failure")
        } catch {
            // Expected — batch should now be on disk.
        }

        // Second "process": cold drain (replayPendingTxnEvents) must see the batch and clear the file.
        let relaunchedStore = TxnPendingEventStore(fileURL: fileURL, clock: { 1_700_000_000_000 })
        let drained = relaunchedStore.drainValid()

        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.first?.instanceId, "instance-bg")
        XCTAssertEqual(drained.first?.first?.data?["confirmationref"], .string("ORD-E2E"))
        XCTAssertTrue(relaunchedStore.drainValid().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
