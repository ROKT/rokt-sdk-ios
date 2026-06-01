import XCTest
@testable import RoktUXHelper

class TestDoubleExtension: XCTestCase {

    func testEqualWithoutPrecision() {
        XCTAssertTrue(Double.equal(1.0, 1.0))
        XCTAssertFalse(Double.equal(1.0, 2.0))
    }

    func testEqualWithPrecision() {
        XCTAssertTrue(Double.equal(1.12345, 1.12346, precise: 4))
        XCTAssertFalse(Double.equal(1.12345, 1.12346, precise: 5))
    }

    func testPrecised() {
        XCTAssertEqual(1.12345.precised(2), 1.12)
        XCTAssertEqual(1.12345.precised(3), 1.123)
        XCTAssertEqual(1.12345.precised(4), 1.1235)
    }
}
