import Foundation
import Security

// Indirection over the credential store: the Keychain in production, an in-memory
// fake in tests, so TxnSessionManager makes no Keychain calls under test.
internal protocol TxnSessionStore: AnyObject {
    func string(forKey key: String) -> String?
    func setString(_ value: String, forKey key: String)
    func removeValue(forKey key: String)
}

// The bearer token is a high-value credential, so it is encrypted at rest in the
// Keychain rather than left in UserDefaults. Items are device-only and available
// after first unlock so a background relaunch can still restore the session.
internal final class KeychainTxnSessionStore: TxnSessionStore {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.rokt.widget") {
        self.service = service
    }

    func string(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        removeValue(forKey: key)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func removeValue(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
