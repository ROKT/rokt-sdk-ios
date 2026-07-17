import Foundation

/// A single unsent events batch awaiting replay.
internal struct TxnPendingEventBatch: Codable, Equatable {
    let events: [TxnEvent]
    let persistedAtMs: Int64
}

/// Persists unsent event batches so they survive a process restart and can be replayed on the
/// next init. Mirrors the web SDK's `RoktTransactionsPendingEvents` store: at most 10 batches,
/// each with a 30-minute TTL.
internal protocol TxnPendingEventStoring {
    /// Persists a batch that failed to send. No-op once the store is full (newest dropped).
    func persist(events: [TxnEvent])
    /// Returns the non-expired batches and clears the store. The caller re-persists any that fail again.
    func drainValid() -> [[TxnEvent]]
}

internal final class TxnPendingEventStore: TxnPendingEventStoring {
    static let maxBatches = 10
    static let ttlMs: Int64 = 30 * 60 * 1000

    private let fileURL: URL?
    private let clock: () -> Int64
    private let queue = DispatchQueue(label: "com.rokt.TxnPendingEventStore")

    init(
        fileURL: URL? = TxnPendingEventStore.defaultFileURL(),
        clock: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.fileURL = fileURL
        self.clock = clock
    }

    // Transient replay data belongs in Caches (excluded from iCloud backup / not user-visible),
    // matching where the font cache lives.
    private static func defaultFileURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("txn_pending_events.json")
    }

    func persist(events: [TxnEvent]) {
        guard let fileURL, !events.isEmpty else { return }
        let now = clock()
        queue.sync {
            // Drop expired entries first so the cap counts only live batches.
            var batches = load(from: fileURL).filter { now - $0.persistedAtMs <= Self.ttlMs }
            // Match web semantics: when full, drop the newest rather than evicting an older batch.
            guard batches.count < Self.maxBatches else { return }
            batches.append(TxnPendingEventBatch(events: events, persistedAtMs: now))
            save(batches, to: fileURL)
        }
    }

    func drainValid() -> [[TxnEvent]] {
        guard let fileURL else { return [] }
        let now = clock()
        return queue.sync {
            let batches = load(from: fileURL)
            try? FileManager.default.removeItem(at: fileURL)
            return batches
                .filter { now - $0.persistedAtMs <= Self.ttlMs }
                .map { $0.events }
        }
    }

    private func load(from url: URL) -> [TxnPendingEventBatch] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([TxnPendingEventBatch].self, from: data)) ?? []
    }

    private func save(_ batches: [TxnPendingEventBatch], to url: URL) {
        guard let data = try? JSONEncoder().encode(batches) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
