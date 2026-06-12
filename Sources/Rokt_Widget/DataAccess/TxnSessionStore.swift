import Foundation

// Test seam so TxnSessionManager can be exercised without real persistent storage.
internal protocol TxnSessionStore: AnyObject {
    func string(forKey key: String) -> String?
    func setString(_ value: String, forKey key: String)
    func removeValue(forKey key: String)
}

// Plain UserDefaults rather than the Keychain: the token is short-lived and
// sandbox-protected, matching the legacy SessionManager and the other SDK platforms.
internal final class UserDefaultsTxnSessionStore: TxnSessionStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func setString(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
