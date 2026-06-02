import XCTest
@testable import RoktUXHelper

class TestEventDateFormatter: XCTestCase {

    func test_convert_date_to_string_date() throws {
        var date = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(EventDateFormatter.getDateString(date), "1970-01-01T00:00:00.000Z")

        date = Date(timeIntervalSince1970: 1730548860.123)
        XCTAssertEqual(EventDateFormatter.getDateString(date), "2024-11-02T12:01:00.123Z")

        date = Date(timeIntervalSince1970: 1730548740.456)
        XCTAssertEqual(EventDateFormatter.getDateString(date), "2024-11-02T11:59:00.456Z")
    }

    func test_convert_string_date_to_date() {
        var date = EventDateFormatter.dateFormatter.date(from: "2024-11-11T00:01:00.456Z")
        XCTAssertEqual(date?.timeIntervalSince1970, 1731283260.456)

        date = EventDateFormatter.dateFormatter.date(from: "2024-11-10T23:59:59.123Z")
        XCTAssertEqual(date?.timeIntervalSince1970, 1731283199.123)
    }
}
