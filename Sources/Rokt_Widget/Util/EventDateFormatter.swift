import Foundation

class EventDateFormatter {
    private static let eventTimeStampFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    private static let utcTimeZone = "UTC"
    private static let baseLocale = "en"

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: baseLocale)
        dateFormatter.dateFormat = eventTimeStampFormat
        dateFormatter.timeZone = TimeZone(abbreviation: utcTimeZone)
        return dateFormatter
    }()

    static func getDateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
