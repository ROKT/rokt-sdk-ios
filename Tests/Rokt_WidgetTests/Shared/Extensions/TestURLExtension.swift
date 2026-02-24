import XCTest
@testable import Rokt_Widget

final class TestURLExtension: XCTestCase {

    func test_isWebURL_withHttpPrefix_returnsTrue() {
        let url = "http://rokt.com"
        let result = URL.isWebURL(url: url)

        XCTAssertTrue(result)
    }

    func test_isWebURL_withHttpsPrefix_returnsTrue() {
        let url = "https://rokt.com"
        let result = URL.isWebURL(url: url)

        XCTAssertTrue(result)
    }

    func test_isWebURL_withUppercasePrefix_returnsTrue() {
        let url = "HTTP://rokt.com"
        let result = URL.isWebURL(url: url)

        XCTAssertTrue(result)
    }

    func test_isWebURL_withMixedCasePrefix_returnsTrue() {
        let url = "Https://rokt.com"
        let result = URL.isWebURL(url: url)

        XCTAssertTrue(result)
    }

    func test_isWebURL_withNonWebURL_returnsFalse() {
        let url = "file:///path/to/file"
        let result = URL.isWebURL(url: url)

        XCTAssertFalse(result)
    }

    func test_isWebURL_instanceMethod_withHttpURL_returnsTrue() {
        let url = URL(string: "http://rokt.com")!
        let result = url.isWebURL()

        XCTAssertTrue(result)
    }

    func test_isWebURL_instanceMethod_withNonWebURL_returnsFalse() {
        let url = URL(fileURLWithPath: "/path/to/file")
        let result = url.isWebURL()

        XCTAssertFalse(result)
    }
}
