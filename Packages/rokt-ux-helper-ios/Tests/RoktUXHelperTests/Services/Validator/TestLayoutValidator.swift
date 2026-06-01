import XCTest
@testable import RoktUXHelper

final class TestLayoutValidator: XCTestCase {

    func test_isValidColor() throws {
        XCTAssertTrue(LayoutValidator.isValidColor("#111111"))
        XCTAssertTrue(LayoutValidator.isValidColor("#AA123123"))
        XCTAssertTrue(LayoutValidator.isValidColor("#FBC"))

        XCTAssertFalse(LayoutValidator.isValidColor("123123"))
        XCTAssertFalse(LayoutValidator.isValidColor("#MMMMMM"))
        XCTAssertFalse(LayoutValidator.isValidColor("234"))
        XCTAssertFalse(LayoutValidator.isValidColor("#Colors"))
    }
}
