// periphery:ignore:all
import Foundation

internal actor TxnSessionManager {
    private enum Keys {
        static let tagId = "ROKT_TXN_TAG_ID"
        static let sessionId = "ROKT_TXN_SESSION_ID"
        static let token = "ROKT_TXN_SESSION_TOKEN"
        static let expiresAt = "ROKT_TXN_TOKEN_EXPIRES_AT"
        // Monotonic counter, bumped only when a session is deliberately invalidated.
        static let epoch = "ROKT_TXN_SESSION_EPOCH"
    }

    // Guards every read-modify-write of the shared store.
    //
    // Actor isolation alone is not enough here: `clearPersistedSession` is deliberately
    // nonisolated (see its docs) and so does not queue behind actor-isolated work. Without this
    // lock it can land between the epoch check and the write inside `update`, so the departing
    // customer's tag, session id and token get written back alongside the *new* epoch — the next
    // manager then treats that stale session as current and the reset is silently undone. Static
    // so it serialises instances against each other and against the nonisolated entry point.
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

    // Epoch observed when this instance was built. A deliberate invalidation bumps the stored
    // epoch, which fences out every instance created before it: an offers/events request that
    // was already in flight cannot write its (now dead) session back when its response lands.
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

    /// Deliberately invalidates the session and fences out in-flight writers.
    ///
    /// Used by the 401 paths. In-memory state on *other* instances is intentionally left alone:
    /// a batch of events already handed to `TxnEventService` must keep sending under the
    /// departing session's token so those events stay attributed to the customer who generated
    /// them.
    ///
    /// Fenced like `update`: a 401 tells us the session *this instance* was built on is dead, and
    /// that says nothing about whichever session is live now. Without the check, an events 401
    /// arriving from the previous customer's request would wipe the session the person currently
    /// at the terminal is already using.
    func clear() {
        Self.storeLock.lock()
        defer { Self.storeLock.unlock() }
        guard isCurrentEpochLocked() else { return }
        clearStateLocked(bumpEpoch: true)
    }

    /// Drops the persisted session and bumps the epoch, synchronously.
    ///
    /// Deliberately not actor-isolated. `Rokt.clearSession()` has to take effect before the
    /// caller's very next `selectPlacements`, and hopping onto the actor would leave a window
    /// where a placement started microseconds later reads the store and rehydrates the session
    /// that was just dropped. Because it bypasses actor isolation it takes `storeLock`, which is
    /// what actually makes it safe against a concurrent `update`.
    nonisolated static func clearPersistedSession(
        store: TxnSessionStore = UserDefaultsTxnSessionStore()
    ) {
        storeLock.lock()
        defer { storeLock.unlock() }
        store.removeValue(forKey: Keys.tagId)
        store.removeValue(forKey: Keys.sessionId)
        store.removeValue(forKey: Keys.token)
        store.removeValue(forKey: Keys.expiresAt)
        let current = Int(store.string(forKey: Keys.epoch) ?? "") ?? 0
        store.setString(String(current &+ 1), forKey: Keys.epoch)
    }

    private var hasExpired: Bool {
        guard let expiresAt else { return true }
        return clock() >= expiresAt
    }

    // MARK: - Store access

    //
    // Everything below assumes `storeLock` is already held by the caller. NSLock is not
    // reentrant, so each public entry point takes it exactly once and these helpers never
    // re-acquire it.

    // In-memory mode has no shared store, so there is nothing to fence against.
    private func isCurrentEpochLocked() -> Bool {
        guard let store else { return true }
        return storedEpochLocked(store) == capturedEpoch
    }

    private func storedEpochLocked(_ store: TxnSessionStore) -> Int {
        Int(store.string(forKey: Keys.epoch) ?? "") ?? 0
    }

    private func restoreFromStore() {
        guard let store, let roktTagId else { return }
        Self.storeLock.lock()
        defer { Self.storeLock.unlock() }
        capturedEpoch = storedEpochLocked(store)
        // Only restore a session bound to the current tag id; otherwise start clean.
        guard store.string(forKey: Keys.tagId) == roktTagId else {
            clearStateLocked(bumpEpoch: false)
            return
        }
        sessionId = store.string(forKey: Keys.sessionId)
        token = store.string(forKey: Keys.token)
        expiresAt = store.string(forKey: Keys.expiresAt)
            .flatMap(Double.init)
            .map { Date(timeIntervalSince1970: $0/1000) }
        // Drop a persisted-but-expired token so we never start with stale state;
        // an expired JWT is dead server-side and a fresh session is minted at init.
        if hasExpired {
            clearStateLocked(bumpEpoch: false)
        }
    }

    // Housekeeping clears (tag-id mismatch, expired-on-restore) must NOT bump the epoch.
    // They run on every service construction once state is stale, and bumping there would
    // fence out a healthy in-flight request that is about to deliver a valid new token.
    private func clearStateLocked(bumpEpoch: Bool) {
        sessionId = nil
        token = nil
        expiresAt = nil
        guard let store else { return }
        store.removeValue(forKey: Keys.tagId)
        store.removeValue(forKey: Keys.sessionId)
        store.removeValue(forKey: Keys.token)
        store.removeValue(forKey: Keys.expiresAt)
        guard bumpEpoch else { return }
        // &+ so a pathologically long-lived install wraps instead of trapping; equality is
        // all this is used for, so wrapping is harmless.
        let next = storedEpochLocked(store) &+ 1
        store.setString(String(next), forKey: Keys.epoch)
        capturedEpoch = next
    }

    private func persistLocked(includeSessionId: Bool) {
        guard let store, let roktTagId else { return }
        // Always record the tag-id binding: restoreFromStore treats a missing/mismatched
        // tag id as another account's data and clears the session, so a token persisted
        // without it would never survive a reload.
        store.setString(roktTagId, forKey: Keys.tagId)
        if includeSessionId, let sessionId {
            store.setString(sessionId, forKey: Keys.sessionId)
        }
        if let token {
            store.setString(token, forKey: Keys.token)
        }
        if let expiresAt {
            store.setString(String(expiresAt.timeIntervalSince1970 * 1000), forKey: Keys.expiresAt)
        }
    }
}
