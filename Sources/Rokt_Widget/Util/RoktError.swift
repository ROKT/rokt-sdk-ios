import Foundation

struct RoktError: ExpressibleByStringLiteral, Error, LocalizedError {

    private let description: String

    var errorDescription: String? {
        description
    }

    init(stringLiteral value: String) {
        description = value
    }
}
