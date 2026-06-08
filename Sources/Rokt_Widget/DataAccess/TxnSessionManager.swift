// periphery:ignore:all - v2 session store; token-refresh/session-id members are consumed by the upcoming v2 offers/events path
import Foundation

internal final class TxnSessionManager {
    // Persistence keys for the v2 path, separate from the legacy SessionManager's `rokt.*` keys.
    private enum Keys {
        static let tagId = "ROKT_TXN_TAG_ID"
        static let sessionId = "ROKT_TXN_SESSION_ID"
        static let token = "ROKT_TXN_SESSION_TOKEN"
        static let expiresAt = "ROKT_TXN_TOKEN_EXPIRES_AT"
    }

    private let clock: () -> Date
    private let lock = NSLock()

    // nil disables persistence (in-memory only), preserving the lightweight test setup.
    private let roktTagId: String?
    private let userDefaults: UserDefaults?

    private(set) var boundTagId: String?
    private var sessionId: String?
    private var token: String?
    private var expiresAt: Date?

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
        self.roktTagId = nil
        self.userDefaults = nil
        self.boundTagId = nil
    }

    init(
        roktTagId: String,
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = Date.init
    ) {
        self.clock = clock
        self.roktTagId = roktTagId
        self.userDefaults = userDefaults
        self.boundTagId = roktTagId
        restoreFromStore()
    }

    var currentSessionId: String? {
        lock.lock()
        defer { lock.unlock() }
        return sessionId
    }

    var isExpired: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isExpiredLocked
    }

    // nil when there is no token or it has expired; the server then mints a
    // fresh session rather than returning 401.
    var authorizationHeader: String? {
        lock.lock()
        defer { lock.unlock() }
        guard let token, !isExpiredLocked else { return nil }
        return "Bearer \(token)"
    }

    func update(sessionId: String, sessionToken: TxnSessionToken) {
        lock.lock()
        defer { lock.unlock() }
        self.sessionId = sessionId
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persist(includeSessionId: true)
    }

    // Token-only refresh for offers/events responses, keeping the session id.
    func update(sessionToken: TxnSessionToken) {
        lock.lock()
        defer { lock.unlock() }
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
        persist(includeSessionId: false)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        sessionId = nil
        token = nil
        expiresAt = nil
        guard let userDefaults else { return }
        userDefaults.removeObject(forKey: Keys.tagId)
        userDefaults.removeObject(forKey: Keys.sessionId)
        userDefaults.removeObject(forKey: Keys.token)
        userDefaults.removeObject(forKey: Keys.expiresAt)
    }

    private var isExpiredLocked: Bool {
        guard let expiresAt else { return true }
        return clock() >= expiresAt
    }

    private func restoreFromStore() {
        guard let userDefaults, let roktTagId else { return }
        // Only restore a session bound to the current tag id; otherwise start clean.
        guard userDefaults.string(forKey: Keys.tagId) == roktTagId else {
            clear()
            return
        }
        sessionId = userDefaults.string(forKey: Keys.sessionId)
        token = userDefaults.string(forKey: Keys.token)
        let storedExpiry = userDefaults.double(forKey: Keys.expiresAt)
        expiresAt = storedExpiry > 0 ? Date(timeIntervalSince1970: storedExpiry/1000) : nil
        // Drop a persisted-but-expired token so we never start with stale state;
        // an expired JWT is dead server-side and a fresh session is minted at init.
        if isExpiredLocked {
            clear()
        }
    }

    private func persist(includeSessionId: Bool) {
        guard let userDefaults, let roktTagId else { return }
        if includeSessionId {
            userDefaults.set(roktTagId, forKey: Keys.tagId)
            userDefaults.set(sessionId, forKey: Keys.sessionId)
        }
        userDefaults.set(token, forKey: Keys.token)
        if let expiresAt {
            userDefaults.set(expiresAt.timeIntervalSince1970 * 1000, forKey: Keys.expiresAt)
        }
    }
}
