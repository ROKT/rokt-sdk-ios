import Foundation

struct TimingMetric: Codable, Equatable {
    let name: TimingType
    let value: Date

    internal func toDictionary() -> [String: String] {
        var dictionary = [String: String]()
        dictionary[BE_NAME] = self.name.rawValue
        dictionary[BE_VALUE] = String(Int(self.value.timeIntervalSince1970 * 1000))
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
