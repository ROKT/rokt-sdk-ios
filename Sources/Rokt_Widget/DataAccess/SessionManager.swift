import Foundation

private let userDefaultsKeyTagId: String = "rokt.tagId"
private let userDefaultsKeySessionId: String = "rokt.sessionId"

private enum SessionInvalidationReason: String {
    case tagIdChanged = "tag_id_changed"
    case sessionIdUpdated = "session_id_updated"
    case sessionCleared = "session_cleared"
}

/// Session id for diagnostics and timings. Offers and events use `TxnSessionManager`.
class SessionManager {
    private let managedSessions: [ManagedSession]
    private let userDefaults: UserDefaults

    init(
        managedSessions: [ManagedSession],
        userDefaults: UserDefaults = .standard
    ) {
        self.managedSessions = managedSessions
        self.userDefaults = userDefaults
    }

    var storedTagId: String? {
        get {
            return userDefaults.string(forKey: userDefaultsKeyTagId)
        }
        set {
            if storedTagId != newValue {
                clearSession(reason: .tagIdChanged)
            }
            userDefaults.set(newValue, forKey: userDefaultsKeyTagId)
        }
    }

    func getCurrentSessionIdWithoutExpiring() -> String? {
        return userDefaults.string(forKey: userDefaultsKeySessionId)
    }

    func updateSessionId(newSessionId: String?) {
        if newSessionId == getCurrentSessionIdWithoutExpiring() {
            RoktLogger.shared.debug("Session update skipped because session id is unchanged: \(newSessionId)")
            return
        }

        clearSession(reason: .sessionIdUpdated)
        userDefaults.set(newSessionId, forKey: userDefaultsKeySessionId)
        RoktLogger.shared.sessionId = newSessionId
        RoktLogger.shared.info("Session updated. sessionId=\(newSessionId)")
    }

    /// Drops the session unconditionally, for an explicit `Rokt.clearSession()`.
    ///
    /// Deliberately not routed through `updateSessionId(nil)`: that path short-circuits when the
    /// stored id already matches, so it would silently skip the managed-session cleanup whenever
    /// there is no id to replace.
    func invalidateSession() {
        clearSession(reason: .sessionCleared)
    }

    private func clearSession(reason: SessionInvalidationReason) {
        RoktLogger.shared.sessionId = nil
        RoktLogger.shared.info("Clearing session. reason=\(reason.rawValue)")
        userDefaults.removeObject(forKey: userDefaultsKeySessionId)
        managedSessions.forEach { $0.sessionInvalidated() }
    }
}

/// Protocol for classes that need to be tied to the Rokt session.
/// When a session expires or is otherwise invalidated the managed class should implement relevant session cleanup.
protocol ManagedSession {
    func sessionInvalidated()
}
