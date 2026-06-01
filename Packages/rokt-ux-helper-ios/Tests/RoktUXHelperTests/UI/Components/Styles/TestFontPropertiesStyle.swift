import XCTest
import SwiftUI
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 13.0, *)
final class TestFontPropertiesStyle: XCTestCase {
    
    func test_converted_weight_default() {
        assert_font_weight(nil, fontWeight: .normal)
    }
    
    func test_converted_weight_thin() {
        assert_font_weight("100", fontWeight: .thin)
    }
    
    func test_converted_weight_ultra_light() {
        assert_font_weight("200", fontWeight: .ultralight)
    }
    
    func test_converted_weight_light() {
        assert_font_weight("300", fontWeight: .light)
    }
    
    func test_converted_weight_normal() {
        assert_font_weight("400", fontWeight: .normal)
    }
    
    func test_converted_weight_medium() {
        assert_font_weight("500", fontWeight: .medium)
    }
    
    func test_converted_weight_semibold() {
        assert_font_weight("600", fontWeight: .semibold)
    }
    
    func test_converted_weight_bold() {
        assert_font_weight("700", fontWeight: .bold)
    }
    
    func test_converted_weight_heavy() {
        assert_font_weight("800", fontWeight: .heavy)
    }
    
    func test_converted_weight_black() {
        assert_font_weight("900", fontWeight: .black)
    }
    
    private func assert_font_weight(_ weight: String?, fontWeight: FontWeightUIModel) {
        // Arrange
        let text = TextStylingProperties(
            textColor: nil,
            fontSize: 10,
            fontFamily: "Arial",
            fontWeight: FontWeight(rawValue: weight ?? ""),
            lineHeight: nil,
            horizontalTextAlign: nil,
            baselineTextAlign: nil,
            fontStyle: nil,
            textTransform: nil,
            letterSpacing: nil,
            textDecoration: nil,
            lineLimit: nil
        )
        // Act
        let convertedWeight = text.convertedWeight
        // Assert
        XCTAssertEqual(convertedWeight, fontWeight)
    }

    func test_init_shouldCalculateValues() throws {
        let rawValues: [String: Any] = [
            "fontSize": 10,
            "fontFamily": "Arial",
            "fontWeight": "100",
            "fontStyle": "italic"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        let sut = try TestConstants.decoder.decode(TextStylingProperties.self, from: data)

        XCTAssertEqual(sut.fontSize, 10)
        XCTAssertEqual(sut.fontFamily, "Arial")
        XCTAssertEqual(sut.fontWeight?.asUIFontWeight, .thin)
        XCTAssertEqual(sut.fontStyle, .italic)

        let targetFont = UIFont(name: "Arial", size: 10)?.withWeight(.thin)

        XCTAssertEqual(sut.weightedUIFont, targetFont)

        let tFont = try XCTUnwrap(targetFont)

        XCTAssertEqual(sut.styledFont, Font(tFont.setItalic()))
        XCTAssertEqual(sut.styledUIFont, tFont.setItalic())
        XCTAssertEqual(sut.convertedWeight, .thin)
    }

    func test_init_withoutStyle_returnsWeightedFont() throws {
        let rawValues: [String: Any] = [
            "fontSize": 10,
            "fontFamily": "Arial",
            "fontWeight": "100"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        let sut = try TestConstants.decoder.decode(TextStylingProperties.self, from: data)

        let weightedFont = try XCTUnwrap(sut.weightedUIFont)

        XCTAssertEqual(sut.styledFont, Font(weightedFont))
        XCTAssertEqual(sut.styledUIFont, weightedFont)
    }

    func test_regularStyle_returnsRegularFont() throws {
        let rawValues: [String: Any] = [
            "size": 10,
            "family": "Arial",
            "weight": "thin",
            "style": "normal"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        let sut = try TestConstants.decoder.decode(TextStylingProperties.self, from: data)

        let weightedFont = try XCTUnwrap(sut.weightedUIFont)

        XCTAssertEqual(sut.styledFont, Font(weightedFont))
        XCTAssertEqual(sut.styledUIFont, weightedFont)
    }
    
    func test_get_scale_size() throws {
        // Arrange
        let fontSize = Float(10)
        // Act
        let small = fontSize.getAsScaledFontSize(contentSize: .extraSmall)
        let large = fontSize.getAsScaledFontSize(contentSize: .extraLarge)
        let medium = fontSize.getAsScaledFontSize(contentSize: .unspecified)
        
        // Assert
        XCTAssertGreaterThan(large, 10)
        XCTAssertLessThan(small, 10)
        XCTAssertEqual(medium, 10)
        
    }
}
