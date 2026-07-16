import Foundation

private let userDefaultsKeyTagId: String = "rokt.tagId"
private let userDefaultsKeySessionId: String = "rokt.sessionId"

private enum SessionInvalidationReason: String {
    case tagIdChanged = "tag_id_changed"
    case sessionIdUpdated = "session_id_updated"
}

/// Persists the legacy `rokt-session-id` used by diagnostics, timings, and cart headers.
/// Session continuity for init/offers/events is owned by `TxnSessionManager` instead.
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
        RoktLogger.shared.info("Session updated. sessionId=\(newSessionId)")
    }

    private func clearSession(reason: SessionInvalidationReason) {
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
