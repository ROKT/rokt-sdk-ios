// periphery:ignore:all
import Foundation

internal actor TxnSessionManager {
    // Actor isolation is not enough: `clearPersistedSession` is nonisolated, so without this it
    // can land between the epoch check and the write in `update` and restore a dropped session.
    private static let storeLock = NSLock()

    private let clock: () -> Date

    // nil disables persistence (in-memory only), preserving the lightweight test setup.
    private let roktTagId: String?
    private let store: TxnSessionStore?

    // Immutable, so it is read synchronously outside the actor in resolveTxnSessionManager.
    nonisolated let boundTagId: String?

    private var sessionId: String?
    private var token: String?
    private var expiresAt: Date?

    // Epoch at construction. A deliberate reset bumps the stored value, fencing out instances
    // built before it so an in-flight response cannot write its dead session back.
    private var capturedEpoch: Int = 0

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
        self.roktTagId = nil
        self.store = nil
        self.boundTagId = nil
    }

    init(
        roktTagId: String,
        store: TxnSessionStore = UserDefaultsTxnSessionStore(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.clock = clock
        self.roktTagId = roktTagId
        self.store = store
        self.boundTagId = roktTagId
        restoreFromStore()
    }

    var currentSessionId: String? {
        sessionId
    }

    var isExpired: Bool {
        hasExpired
    }

    // nil when there is no token or it has expired; the server then mints a
    // fresh session rather than returning 401.
    var authorizationHeader: String? {
        guard let token, !hasExpired else { return nil }
        return "Bearer \(token)"
    }

    func update(sessionId: String, sessionToken: TxnSessionToken) {
        Self.storeLock.lock()
        defer { Self.storeLock.unlock() }
        guard isCurrentEpochLocked() else { return }
        self.sessionId = sessionId
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persistLocked(includeSessionId: true)
    }

    // Token-only refresh for events responses (they carry no session id), keeping the session id.
    func update(sessionToken: TxnSessionToken) {
        Self.storeLock.lock()
        defer { Self.storeLock.unlock() }
        guard isCurrentEpochLocked() else { return }
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persistLocked(includeSessionId: false)
    }

    /// Invalidates the session and fences out in-flight writers.
    ///
    /// Fenced itself: a 401 means the session *this* instance was built on is dead, which says
    /// nothing about the session that is live now. Other instances keep their in-memory token so
    /// events already dispatched stay attributed to the customer who generated them.
    func clear() {
        Self.storeLock.lock()
        defer { Self.storeLock.unlock() }
        guard isCurrentEpochLocked() else { return }
        clearStateLocked(bumpEpoch: true)
    }

    /// Drops the persisted session and bumps the epoch, synchronously.
    ///
    /// Nonisolated so `Rokt.clearSession()` takes effect before the caller's next
    /// `selectPlacements`; hopping onto the actor would let a placement started microseconds
    /// later rehydrate what was just dropped. Takes `storeLock` because it bypasses isolation.
    nonisolated static func clearPersistedSession(
        store: TxnSessionStore = UserDefaultsTxnSessionStore()
    ) {
        storeLock.lock()
        defer { storeLock.unlock() }
        TxnSessionPersistence.clear(store: store)
        let current = Int(store.string(forKey: TxnSessionStoreKeys.epoch) ?? "") ?? 0
        store.setString(String(current &+ 1), forKey: TxnSessionStoreKeys.epoch)
    }

    private var hasExpired: Bool {
        TxnSessionPersistence.isExpired(expiresAt: expiresAt, clock: clock)
    }

    // MARK: - Store access (callers must already hold `storeLock`; NSLock is not reentrant)

    private func isCurrentEpochLocked() -> Bool {
        guard let store else { return true }
        return storedEpochLocked(store) == capturedEpoch
    }

    private func storedEpochLocked(_ store: TxnSessionStore) -> Int {
        Int(store.string(forKey: TxnSessionStoreKeys.epoch) ?? "") ?? 0
    }

    private func restoreFromStore() {
        guard let store, let roktTagId else { return }
        Self.storeLock.lock()
        defer { Self.storeLock.unlock() }
        capturedEpoch = storedEpochLocked(store)
        // Only restore a session bound to the current tag id; otherwise start clean.
        guard store.string(forKey: TxnSessionStoreKeys.tagId) == roktTagId else {
            clearStateLocked(bumpEpoch: false)
            return
        }
        let raw = TxnSessionPersistence.readRaw(store: store)
        sessionId = raw.sessionId
        token = raw.token
        expiresAt = raw.expiresAt
        // An expired JWT is dead server-side; start clean and let init mint a fresh session.
        if hasExpired {
            clearStateLocked(bumpEpoch: false)
        }
    }

    // Housekeeping clears (tag-id mismatch, expired-on-restore) must not bump the epoch: they run
    // on every construction once state is stale, and would fence a healthy in-flight writer.
    private func clearStateLocked(bumpEpoch: Bool) {
        sessionId = nil
        token = nil
        expiresAt = nil
        guard let store else { return }
        TxnSessionPersistence.clear(store: store)
        guard bumpEpoch else { return }
        let next = storedEpochLocked(store) &+ 1
        store.setString(String(next), forKey: TxnSessionStoreKeys.epoch)
        capturedEpoch = next
    }

    private func persistLocked(includeSessionId: Bool) {
        guard let store, let roktTagId else { return }
        TxnSessionPersistence.persist(
            roktTagId: roktTagId,
            sessionId: sessionId,
            token: token,
            expiresAt: expiresAt,
            includeSessionId: includeSessionId,
            store: store
        )
    }
}
