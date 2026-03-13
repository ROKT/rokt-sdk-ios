import Foundation

class RoktSDKDateHandler {
    static var customDate: Date?

    static func currentDate() -> Date {
        return self.customDate ?? Date()
    }
}
