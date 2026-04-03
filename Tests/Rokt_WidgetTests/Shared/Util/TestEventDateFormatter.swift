import XCTest
@testable import Rokt_Widget

class TestEventDateFormatter: XCTestCase {

    func test_date_formatter() throws {
        let date = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(EventDateFormatter.getDateString(date), "1970-01-01T00:00:00.000Z")
    }
}
