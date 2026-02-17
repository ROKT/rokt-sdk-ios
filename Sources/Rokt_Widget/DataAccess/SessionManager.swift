import Foundation

private let userDefaultsKeyTagId: String = "rokt.tagId"
private let userDefaultsKeySessionId: String = "rokt.sessionId"
private let userDefaultsKeySessionUsageCount: String = "rokt.sessionUsageCount"
private let userDefaultsKeyLastExecuteCallDate: String = "rokt.lastExecuteCallDate"
private let userDefaultsKeyCurrentSessionDuration: String = "rokt.currentSessionDuration"

private let maxSessionDurationSeconds: TimeInterval = 30 * 60
private let maxExecuteCallsPerSession: Int = 50

/// Class that manages the Rokt session and handles expiry
///
/// Sessions should last:
///  - Until partner tagId changes
///  - Between app runs
///  - For 50 experiences calls
///  - After 30 minutes (or the updated duration from the API) since the last experiences call
class SessionManager {
    private let managedSessions: [ManagedSession]
    private let userDefaults: UserDefaults
    private let dateProvider: () -> Date

    init(
        managedSessions: [ManagedSession],
        userDefaults: UserDefaults = .standard,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.managedSessions = managedSessions
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
    }

    private var sessionUsageCount: Int {
        get {
            return userDefaults.integer(forKey: userDefaultsKeySessionUsageCount)
        }
        set {
            userDefaults.set(newValue, forKey: userDefaultsKeySessionUsageCount)
        }
    }
    private var lastExecuteCallDate: Date? {
        get {
            return userDefaults.object(forKey: userDefaultsKeyLastExecuteCallDate) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: userDefaultsKeyLastExecuteCallDate)
        }
    }
    var storedTagId: String? {
        get {
            return userDefaults.string(forKey: userDefaultsKeyTagId)
        }
        set {
            if storedTagId != newValue {
                clearSession()
            }
            userDefaults.set(newValue, forKey: userDefaultsKeyTagId)
        }
    }
    var currentSessionDurationSeconds: TimeInterval {
        get {
            if userDefaults.object(forKey: userDefaultsKeyCurrentSessionDuration) != nil {
                let currentSessionDuration = userDefaults.double(forKey: userDefaultsKeyCurrentSessionDuration)
                return currentSessionDuration
            } else {
                return maxSessionDurationSeconds
            }
        }
        set {
            userDefaults.set(newValue, forKey: userDefaultsKeyCurrentSessionDuration)
        }
    }

    func getCurrentSessionIdForLayoutRequest() -> String? {
        sessionUsageCount += 1

        if !isValidSession() {
            clearSession()
            return nil
        }
        lastExecuteCallDate = dateProvider()

        return userDefaults.string(forKey: userDefaultsKeySessionId)
    }

    func getCurrentSessionIdWithoutExpiring() -> String? {
        return userDefaults.string(forKey: userDefaultsKeySessionId)
    }

    func updateSessionId(newSessionId: String?) {
        if newSessionId == getCurrentSessionIdWithoutExpiring() {
            return
        }

        clearSession()
        lastExecuteCallDate = dateProvider()
        userDefaults.set(newSessionId, forKey: userDefaultsKeySessionId)
    }

    private func isValidSession() -> Bool {
        return !hasSessionExpired() && isSessionUsageUnderThreshold()
    }

    private func hasSessionExpired() -> Bool {
        if lastExecuteCallDate == nil {
            return false
        }

        let currentTime = dateProvider()
        let timeSinceLastExecuteCall = currentTime.timeIntervalSince(lastExecuteCallDate!)
        let expired = timeSinceLastExecuteCall > currentSessionDurationSeconds
        return expired
    }

    private func isSessionUsageUnderThreshold() -> Bool {
        return sessionUsageCount <= maxExecuteCallsPerSession
    }

    private func clearSession() {
        userDefaults.removeObject(forKey: userDefaultsKeySessionId)
        userDefaults.removeObject(forKey: userDefaultsKeySessionUsageCount)
        userDefaults.removeObject(forKey: userDefaultsKeyLastExecuteCallDate)
        managedSessions.forEach { $0.sessionInvalidated() }
    }
}

/// Protocol for classes that need to be tied to the Rokt session.
/// When a session expires or is otherwise invalidated the managed class should implement relevant session cleanup.
protocol ManagedSession {
    func sessionInvalidated()
}
