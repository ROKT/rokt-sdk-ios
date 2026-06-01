import XCTest
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 13, *)
final class TestTextStyleModel: XCTestCase {

    func test_get_baseline_offset_form_superscript() {
        // Arrang
        guard let font = UIFont(name: "Arial", size: 18) else {
            XCTFail()
            return
        }
        let textStylingProperties = TextStylingProperties(
            textColor: nil,
            fontSize: 18,
            fontFamily: "Arial",
            fontWeight: .w100,
            lineHeight: nil,
            horizontalTextAlign: nil,
            baselineTextAlign: .super,
            fontStyle: nil,
            textTransform: nil,
            letterSpacing: nil,
            textDecoration: nil,
            lineLimit: nil
        )
        // Act
        let baseline = textStylingProperties.baselineOffset
        // Assert
        XCTAssertEqual(baseline, font.ascender * 0.5)
    }

    func test_get_baseline_offset_form_subscript() {
        // Arrang
        guard let font = UIFont(name: "Arial", size: 18) else {
            XCTFail()
            return
        }
        let textStylingProperties = TextStylingProperties(
            textColor: nil,
            fontSize: 18,
            fontFamily: "Arial",
            fontWeight: nil,
            lineHeight: nil,
            horizontalTextAlign: nil,
            baselineTextAlign: .sub,
            fontStyle: nil,
            textTransform: nil,
            letterSpacing: nil,
            textDecoration: nil,
            lineLimit: nil
        )
        // Act
        let baseline = textStylingProperties.baselineOffset
        // Assert
        XCTAssertEqual(baseline, font.ascender * -0.5)
    }

}
