import Foundation

extension Sequence {
    /// Groups elements by `key`, keeping groups in first-appearance order and elements in
    /// sequence order (`Dictionary(grouping:by:)` leaves the group order undefined).
    func grouped<Key: Hashable>(by key: (Element) -> Key) -> [(key: Key, elements: [Element])] {
        var order: [Key] = []
        var groups: [Key: [Element]] = [:]
        for element in self {
            let groupKey = key(element)
            if groups[groupKey] == nil {
                order.append(groupKey)
            }
            groups[groupKey, default: []].append(element)
        }
        return order.map { (key: $0, elements: groups[$0] ?? []) }
    }
}
