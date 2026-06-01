import Foundation

struct StatePseudoTypes<T>: Decodable, Hashable where T: Decodable, T: Hashable {
    let `default`: T?
    let pressed: T?
    let focused: T?
    let hovered: T?
    let disabled: T?
}
