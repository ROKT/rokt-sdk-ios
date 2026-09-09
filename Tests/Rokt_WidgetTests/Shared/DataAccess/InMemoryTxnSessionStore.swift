@testable import Rokt_Widget

/// Dictionary-backed session store for tests that read back what a service persisted.
final class InMemoryTxnSessionStore: TxnSessionStore {
    private var values: [String: String] = [:]
    func string(forKey key: String) -> String? { values[key] }
    func setString(_ value: String, forKey key: String) { values[key] = value }
    func removeValue(forKey key: String) { values[key] = nil }
}
