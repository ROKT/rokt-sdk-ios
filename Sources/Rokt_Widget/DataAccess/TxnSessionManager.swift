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
    // Without this, a response arriving moments after a reset silently restores the previous
    // customer's session and the next placement continues it.
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
        guard isCurrentEpoch else { return }
        self.sessionId = sessionId
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persist(includeSessionId: true)
    }

    // Token-only refresh for events responses (they carry no session id), keeping the session id.
    func update(sessionToken: TxnSessionToken) {
        guard isCurrentEpoch else { return }
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persist(includeSessionId: false)
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
        guard isCurrentEpoch else { return }
        clearState(bumpEpoch: true)
    }

    /// Drops the persisted session and bumps the epoch, synchronously.
    ///
    /// Deliberately not actor-isolated. `Rokt.clearSession()` has to take effect before the
    /// caller's very next `selectPlacements`, and hopping onto the actor would leave a window
    /// where a placement started microseconds later reads the store and rehydrates the session
    /// that was just dropped. `UserDefaults` is safe to touch from any thread, and every future
    /// `TxnSessionManager` sources its state from the store, so wiping it here invalidates
    /// instances that do not exist yet as well as fencing the ones that already do.
    nonisolated static func clearPersistedSession(
        store: TxnSessionStore = UserDefaultsTxnSessionStore()
    ) {
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

    // In-memory mode has no shared store, so there is nothing to fence against.
    private var isCurrentEpoch: Bool {
        guard let store else { return true }
        return storedEpoch(store) == capturedEpoch
    }

    private func storedEpoch(_ store: TxnSessionStore) -> Int {
        Int(store.string(forKey: Keys.epoch) ?? "") ?? 0
    }

    private func restoreFromStore() {
        guard let store, let roktTagId else { return }
        capturedEpoch = storedEpoch(store)
        // Only restore a session bound to the current tag id; otherwise start clean.
        guard store.string(forKey: Keys.tagId) == roktTagId else {
            clearState(bumpEpoch: false)
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
            clearState(bumpEpoch: false)
        }
    }

    // Housekeeping clears (tag-id mismatch, expired-on-restore) must NOT bump the epoch.
    // They run on every service construction once state is stale, and bumping there would
    // fence out a healthy in-flight request that is about to deliver a valid new token.
    private func clearState(bumpEpoch: Bool) {
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
        let next = storedEpoch(store) &+ 1
        store.setString(String(next), forKey: Keys.epoch)
        capturedEpoch = next
    }

    private func persist(includeSessionId: Bool) {
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
