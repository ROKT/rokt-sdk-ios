import Foundation

private let nameKey = "name"
private let valueKey = "value"

struct TimingMetric: Codable, Equatable {
    let name: TimingType
    let value: Date

    internal func toDictionary() -> [String: String] {
        var dictionary = [String: String]()
        dictionary[nameKey] = self.name.rawValue
        dictionary[valueKey] = String(Int(self.value.timeIntervalSince1970 * 1000))
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
