import XCTest
@testable import Rokt_Widget

final class TestTxnPendingEventStore: XCTestCase {

    private var fileURL: URL!
    private var nowMs: Int64!

    override func setUp() {
        super.setUp()
        nowMs = 1_700_000_000_000
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("txn_pending_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        fileURL = nil
        nowMs = nil
        super.tearDown()
    }

    private func makeStore() -> TxnPendingEventStore {
        TxnPendingEventStore(fileURL: fileURL, clock: { self.nowMs })
    }

    private func batch(_ id: String) -> [TxnEvent] {
        [TxnEvent(eventType: "impression", instanceId: id, timestamp: 1_700_000_000_000, data: ["k": "v"])]
    }

    func test_persist_thenDrain_returnsBatch() {
        let store = makeStore()
        store.persist(events: batch("a"))

        let drained = store.drainValid()

        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.first?.instanceId, "a")
    }

    func test_drain_clearsStore() {
        let store = makeStore()
        store.persist(events: batch("a"))

        _ = store.drainValid()

        XCTAssertTrue(store.drainValid().isEmpty)
    }

    func test_persist_emptyEvents_isNoOp() {
        let store = makeStore()
        store.persist(events: [])

        XCTAssertTrue(store.drainValid().isEmpty)
    }

    func test_drain_dropsExpiredBatches() {
        let store = makeStore()
        store.persist(events: batch("old"))

        // Advance past the 30-minute TTL before draining.
        nowMs += TxnPendingEventStore.ttlMs + 1

        XCTAssertTrue(store.drainValid().isEmpty)
    }

    func test_drain_keepsBatchExactlyAtTTLBoundary() {
        let store = makeStore()
        store.persist(events: batch("edge"))

        nowMs += TxnPendingEventStore.ttlMs // still within TTL (<=)

        XCTAssertEqual(store.drainValid().count, 1)
    }

    func test_persist_enforcesCapOf10_dropsNewest() {
        let store = makeStore()
        for index in 0..<12 {
            store.persist(events: batch("batch-\(index)"))
        }

        let drained = store.drainValid()

        XCTAssertEqual(drained.count, TxnPendingEventStore.maxBatches)
        // Oldest 10 are kept; the 11th and 12th were dropped.
        XCTAssertEqual(drained.first?.first?.instanceId, "batch-0")
        XCTAssertEqual(drained.last?.first?.instanceId, "batch-9")
    }

    func test_expiredBatchesDoNotConsumeCapacity() {
        let store = makeStore()
        store.persist(events: batch("stale"))

        // Expire the first batch, then fill to cap: all 10 fresh batches should be retained.
        nowMs += TxnPendingEventStore.ttlMs + 1
        for index in 0..<TxnPendingEventStore.maxBatches {
            store.persist(events: batch("fresh-\(index)"))
        }

        let drained = store.drainValid()
        XCTAssertEqual(drained.count, TxnPendingEventStore.maxBatches)
        XCTAssertFalse(drained.contains { $0.first?.instanceId == "stale" })
    }
}
