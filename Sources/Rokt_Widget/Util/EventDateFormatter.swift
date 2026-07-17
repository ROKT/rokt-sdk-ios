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

    /// Parses an event-time string to epoch milliseconds, falling back to now when unparseable.
    static func epochMilliseconds(from eventTime: String) -> Int64 {
        if let date = dateFormatter.date(from: eventTime) {
            return Int64(date.timeIntervalSince1970 * 1000)
        }
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
