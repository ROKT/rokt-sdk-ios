import Foundation

struct TimingMetric: Codable, Equatable {
    private static let nameKey = "name"
    private static let valueKey = "value"

    let name: TimingType
    let value: Date

    internal func toDictionary() -> [String: String] {
        var dictionary = [String: String]()
        dictionary[Self.nameKey] = self.name.rawValue
        dictionary[Self.valueKey] = String(Int(self.value.timeIntervalSince1970 * 1000))
        return dictionary
    }
}

enum TimingType: String, Codable {
    case initStart
    case initEnd
    case pageInit
    case selectionStart
    case selectionEnd
    case experiencesRequestStart
    case experiencesRequestEnd
    case placementInteractive
    case jointSdkSelectPlacements
}
