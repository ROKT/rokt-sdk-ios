import XCTest
@testable import RoktUXHelper
import DcuiSchema

final class FontWeightExtensionTests: XCTestCase {
    func test_asUIFontWeight_shouldReturnDistinctWeight() {
        XCTAssertEqual(FontWeight.w100.asUIFontWeight, .thin)
        XCTAssertEqual(FontWeight.w200.asUIFontWeight, .ultraLight)
        XCTAssertEqual(FontWeight.w300.asUIFontWeight, .light)
        XCTAssertEqual(FontWeight.w400.asUIFontWeight, .regular)
        XCTAssertEqual(FontWeight.w500.asUIFontWeight, .medium)
        XCTAssertEqual(FontWeight.w600.asUIFontWeight, .semibold)
        XCTAssertEqual(FontWeight.w700.asUIFontWeight, .bold)
        XCTAssertEqual(FontWeight.w800.asUIFontWeight, .heavy)
        XCTAssertEqual(FontWeight.w900.asUIFontWeight, .black)
    }
}
