import Foundation

/// Buffers events that failed to POST to `/v2/sessions/events` because the session was rejected
/// (401). The events endpoint cannot mint a session — only `/v2/sessions/offers` can — so instead
/// of dropping the events we hold them here and re-send them on the next `TxnEventService.send`,
/// by which point an offers call has typically minted a fresh session/token to attribute them to.
internal actor TxnPendingEventsStore {
    static let shared = TxnPendingEventsStore()

    // Bounds memory if a fresh session is never minted; the oldest events are dropped past the cap.
    private let capacity: Int
    private var pending: [TxnEvent] = []

    init(capacity: Int = 100) {
        self.capacity = capacity
    }

    func add(_ events: [TxnEvent]) {
        guard !events.isEmpty else { return }
        pending.append(contentsOf: events)
        if pending.count > capacity {
            let overflow = pending.count - capacity
            pending.removeFirst(overflow)
            RoktLogger.shared.error("Pending txn events buffer over capacity; dropped \(overflow) oldest event(s)")
        }
    }

    /// Returns the buffered events and empties the buffer.
    func drain() -> [TxnEvent] {
        defer { pending.removeAll() }
        return pending
    }

    var count: Int { pending.count }
}
