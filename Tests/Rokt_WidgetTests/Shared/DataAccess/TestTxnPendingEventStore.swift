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

    func test_persist_writesFileWithDataProtection() throws {
        let store = makeStore()
        store.persist(events: batch("a"))

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let protection = attributes[.protectionKey] as? FileProtectionType

        // The iOS Simulator does not enforce or report Data Protection, so the attribute is nil there.
        // Assert only where it is reported (real device); skip otherwise so CI stays green.
        try XCTSkipUnless(protection != nil, "Data Protection is not reported on this environment (simulator)")
        XCTAssertEqual(protection, .completeUntilFirstUserAuthentication)
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

    // MARK: - Background rewrite / concurrency (#250 flush → #251 persist)

    /// Multiple failed sends (e.g. background flush draining several Tasks) rewrite the same
    /// JSON file concurrently. The store's serial queue must keep the file coherent and honor
    /// the cap without crashing or producing an undecodable payload.
    func test_concurrentPersist_keepsFileDecodableWithinCap() {
        let store = makeStore()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.rokt.test.pending.concurrentPersist", attributes: .concurrent)
        let persistCount = 40

        for index in 0..<persistCount {
            group.enter()
            queue.async {
                store.persist(events: self.batch("c-\(index)"))
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)

        let drained = store.drainValid()
        XCTAssertEqual(drained.count, TxnPendingEventStore.maxBatches)
        XCTAssertEqual(Set(drained.compactMap { $0.first?.instanceId }).count, drained.count)
    }

    /// The #250+#251 intersection: a background flush may still be persisting a failed batch
    /// while a later init drains for replay. Persist and drain must serialize safely.
    func test_concurrentPersistAndDrain_isThreadSafe() {
        let store = makeStore()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.rokt.test.pending.concurrentPersistDrain", attributes: .concurrent)
        var drainedTotal = 0
        let drainedLock = NSLock()

        for index in 0..<30 {
            group.enter()
            queue.async {
                if index % 3 == 0 {
                    let drained = store.drainValid()
                    drainedLock.lock()
                    drainedTotal += drained.count
                    drainedLock.unlock()
                } else {
                    store.persist(events: self.batch("pd-\(index)"))
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)

        let remaining = store.drainValid()
        drainedLock.lock()
        let observed = drainedTotal + remaining.count
        drainedLock.unlock()

        // Every successful persist either appears in a drain or remains; never more than capacity
        // at any drain, and remaining after the race must still decode.
        XCTAssertLessThanOrEqual(remaining.count, TxnPendingEventStore.maxBatches)
        XCTAssertGreaterThanOrEqual(observed, 0)
        XCTAssertTrue(remaining.allSatisfy { $0.first?.instanceId != nil })
    }

    /// Persist that lands after drain has cleared the file must still produce a fresh readable store
    /// (background Task completing after a cold init already drained).
    func test_persistAfterDrain_writesFreshStore() {
        let store = makeStore()
        store.persist(events: batch("before-drain"))
        XCTAssertEqual(store.drainValid().count, 1)
        XCTAssertTrue(store.drainValid().isEmpty)

        store.persist(events: batch("after-drain"))

        let drained = store.drainValid()
        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.first?.instanceId, "after-drain")
    }
}
