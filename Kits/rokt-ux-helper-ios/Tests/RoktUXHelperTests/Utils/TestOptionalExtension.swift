import XCTest
@testable import RoktUXHelper

class TestOptionalExtension: XCTestCase {

    enum TestError: Error {
        case unwrappingFailed
    }

    func testUnwrapSuccess() {
        let optionalValue: Int? = 42
        XCTAssertNoThrow(try {
            let value = try optionalValue.unwrap(orThrow: TestError.unwrappingFailed)
            XCTAssertEqual(value, 42)
        }())
    }

    func testUnwrapFailure() {
        let optionalValue: Int? = nil
        do {
            _ = try optionalValue.unwrap(orThrow: TestError.unwrappingFailed)
            XCTFail("Expected to throw an error, but unwrapped successfully")
        } catch {
            XCTAssertEqual(error as? TestError, TestError.unwrappingFailed)
        }
    }
}
