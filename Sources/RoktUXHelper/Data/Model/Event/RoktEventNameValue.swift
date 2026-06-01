import Foundation
public struct RoktEventNameValue: Codable, Hashable, Equatable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    public func getDictionary() -> [String: String] {
        var dictionary = [String: String]()
        dictionary[BE_NAME] = self.name
        dictionary[BE_VALUE] = self.value
        return dictionary
    }
}
