import Foundation

final class ThreadSafeSet<Element: Hashable>: @unchecked Sendable {
    private var storage = Set<Element>()
    private let lock = NSLock()

    convenience init(_ array: [Element]) {
        self.init()
        array.forEach { _ = insert($0) }
    }

    func insert(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        lock.lock()
        defer { lock.unlock() }
        return storage.insert(element)
    }

    // periphery:ignore - used by tests
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    // periphery:ignore - used by tests
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    // periphery:ignore - used by tests
    func contains(_ member: Element) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.contains(member)
    }

    // periphery:ignore - used by tests
    func remove(_ member: Element) -> Element? {
        lock.lock()
        defer { lock.unlock() }
        return storage.remove(member)
    }

    var allElements: Set<Element> {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
