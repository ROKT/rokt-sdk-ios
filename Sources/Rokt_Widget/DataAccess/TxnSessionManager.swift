// periphery:ignore:all - v2 session store; token-refresh/session-id members are consumed by the upcoming v2 offers/events path
import Foundation

internal actor TxnSessionManager {
    // Persistence keys for the v2 path, separate from the legacy SessionManager's `rokt.*` keys.
    private enum Keys {
        static let tagId = "ROKT_TXN_TAG_ID"
        static let sessionId = "ROKT_TXN_SESSION_ID"
        static let token = "ROKT_TXN_SESSION_TOKEN"
        static let expiresAt = "ROKT_TXN_TOKEN_EXPIRES_AT"
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
        self.sessionId = sessionId
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persist(includeSessionId: true)
    }

    // Token-only refresh for offers/events responses, keeping the session id.
    func update(sessionToken: TxnSessionToken) {
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persist(includeSessionId: false)
    }

    // Export the current session as a shareable bundle for a non-native
    // integration (e.g. a WSDK WebView). nil when there is no live session or
    // the token has expired — a stale token is useless to the other side and
    // would only cause it to re-init.
    var sharedSession: TxnSharedSession? {
        lock.lock()
        defer { lock.unlock() }
        guard let token, let expiresAt, !isExpiredLocked else { return nil }
        return TxnSharedSession(token: token, expiresAtDate: expiresAt)
    }

    // Adopt a session minted by another integration so the next /v2/sessions/init
    // sends this token and the gateway continues the SAME session rather than
    // minting a new one. Seeding an already-expired bundle is a no-op: it would
    // be dropped at init anyway, and clearing here would silently discard a live
    // native session in favour of a dead one. Persists like any other session so
    // it survives a relaunch before init runs.
    //
    // Provenance note (LO-03): an imported session originates from another
    // integration but is intentionally persisted under the local `Keys.tagId`
    // (= roktTagId), becoming a first-class native session for this tag. On
    // relaunch `restoreFromStore` treats it like any other session for this tag;
    // the imported origin is deliberately not recorded — by design the bundle
    // becomes "this app's" session. No behavioural change is needed here.
    func seed(sharedSession shared: TxnSharedSession) {
        lock.lock()
        defer { lock.unlock() }
        // Reject a blank credential before mutating state. A blank token would
        // otherwise clobber a live native session and yield a useless "Bearer "
        // header, forcing a fresh session — a malformed import must never destroy
        // a good session. The session id is not supplied by the bundle (it lives
        // in the token's JWT `sub`); the gateway's init response populates the
        // internal session id via `update(sessionId:sessionToken:)`.
        guard !shared.token.isEmpty else { return }
        guard clock() < shared.expiresAtDate else { return }
        token = shared.token
        expiresAt = shared.expiresAtDate
        // persist guards `if let sessionId`, so seeding with a nil internal
        // session id still persists the tagId binding, token, and expiry.
        persist(includeSessionId: true)
    }

    func clear() {
        sessionId = nil
        token = nil
        expiresAt = nil
        guard let store else { return }
        store.removeValue(forKey: Keys.tagId)
        store.removeValue(forKey: Keys.sessionId)
        store.removeValue(forKey: Keys.token)
        store.removeValue(forKey: Keys.expiresAt)
    }

    private var hasExpired: Bool {
        guard let expiresAt else { return true }
        return clock() >= expiresAt
    }

    private func restoreFromStore() {
        guard let store, let roktTagId else { return }
        // Only restore a session bound to the current tag id; otherwise start clean.
        guard store.string(forKey: Keys.tagId) == roktTagId else {
            clear()
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
            clear()
        }
    }

    private func persist(includeSessionId: Bool) {
        guard let store, let roktTagId else { return }
        if includeSessionId {
            store.setString(roktTagId, forKey: Keys.tagId)
            if let sessionId {
                store.setString(sessionId, forKey: Keys.sessionId)
            }
        }
        if let token {
            store.setString(token, forKey: Keys.token)
        }
        if let expiresAt {
            store.setString(String(expiresAt.timeIntervalSince1970 * 1000), forKey: Keys.expiresAt)
        }
    }
}
