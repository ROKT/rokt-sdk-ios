import XCTest
@testable import RoktUXHelper

final class PlaceholderValidatorTests: XCTestCase {
    var sut: PlaceholderValidator? = PlaceholderValidator()

    override func setUp() {
        super.setUp()

        sut = PlaceholderValidator()
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }

    func test_isValid_withValidCreativeCopyPayload_returnsTrue() {
        let str = "DATA.creativeCopy.title"

        XCTAssertEqual(sut?.isValid(data: str), true)
    }

    func test_isValid_withValidCreativeResponsePayload_returnsTrue() {
        let str = "DATA.creativeResponse.title"

        XCTAssertEqual(sut?.isValid(data: str), true)
    }

    func test_isValid_withSingleValueNoNamespace_returnsFalse() {
        let str = "creative.title"

        XCTAssertEqual(sut?.isValid(data: str), false)
    }

    func test_isValid_withInvalidNamespace_returnsFalse() {
        let str = "DATAT.creative.title"

        XCTAssertEqual(sut?.isValid(data: str), false)
    }

    func test_isValid_withMultipleValidBindings_returnsTrue() {
        let str = "DATA.creativeResponse.title|DATA.creativeCopy.creative.copy"

        XCTAssertEqual(sut?.isValid(data: str), true)
    }

    func test_isValid_withMultipleValidBindingsAndDefaultValue_returnsTrue() {
        let str = "DATA.creativeResponse.title|DATA.creativeCopy.creative.copy|Are you ready to party"

        XCTAssertEqual(sut?.isValid(data: str), true)
    }
}
