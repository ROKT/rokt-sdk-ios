import Foundation

extension Optional {

    var isNil: Bool {
        switch self {
        case .none:
            true
        case .some:
            false
        }
    }

    func unwrap(orThrow error: @autoclosure () -> Error) throws -> Wrapped {
        guard let unwrapped = self else {
            throw error()
        }
        return unwrapped
    }
}
