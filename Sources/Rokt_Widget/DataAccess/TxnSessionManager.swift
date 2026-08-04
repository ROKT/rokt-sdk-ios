// periphery:ignore:all
import Foundation

internal actor TxnSessionManager {
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

    // Token-only refresh for events responses (they carry no session id), keeping the session id.
    func update(sessionToken: TxnSessionToken) {
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persist(includeSessionId: false)
    }

    func clear() {
        sessionId = nil
        token = nil
        expiresAt = nil
        guard let store else { return }
        TxnSessionPersistence.clear(store: store)
    }

    private var hasExpired: Bool {
        TxnSessionPersistence.isExpired(expiresAt: expiresAt, clock: clock)
    }

    private func restoreFromStore() {
        guard let store, let roktTagId else { return }
        // Only restore a session bound to the current tag id; otherwise start clean.
        guard store.string(forKey: TxnSessionStoreKeys.tagId) == roktTagId else {
            clear()
            return
        }
        let raw = TxnSessionPersistence.readRaw(store: store)
        sessionId = raw.sessionId
        token = raw.token
        expiresAt = raw.expiresAt
        // Drop a persisted-but-expired token so we never start with stale state;
        // an expired JWT is dead server-side and a fresh session is minted at init.
        if hasExpired {
            clear()
        }
    }

    private func persist(includeSessionId: Bool) {
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
