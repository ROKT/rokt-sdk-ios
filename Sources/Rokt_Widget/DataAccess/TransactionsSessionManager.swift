// periphery:ignore:all - net-new v2 session store, not yet wired into the live path
import Foundation

internal final class TransactionsSessionManager {
    private let clock: () -> Date
    private let lock = NSLock()

    private var sessionId: String?
    private var token: String?
    private var expiresAt: Date?

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
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

    func update(sessionId: String, sessionToken: V2SessionToken) {
        lock.lock()
        defer { lock.unlock() }
        self.sessionId = sessionId
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
    }

    // Token-only refresh for offers/events responses, keeping the session id.
    func update(sessionToken: V2SessionToken) {
        lock.lock()
        defer { lock.unlock() }
        token = sessionToken.token
        expiresAt = sessionToken.expiresAtDate
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        sessionId = nil
        token = nil
        expiresAt = nil
    }

    private var isExpiredLocked: Bool {
        guard let expiresAt else { return true }
        return clock() >= expiresAt
    }
}
