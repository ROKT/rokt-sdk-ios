import XCTest
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 13, *)
final class TestThemeColor: XCTestCase {
    
    func test_theme_color() throws {
        // Arrange
        let color = ThemeColor(light: "#FFFFFF", dark: "#000000")
        // Act
        var adaptiveColor = "#FFFFFF"
        if UITraitCollection.current.userInterfaceStyle == .dark {
            adaptiveColor = "#000000"
            // Assert
            XCTAssertEqual(adaptiveColor, color.getAdaptiveColor(.dark))
        }
        // Assert
        XCTAssertEqual(adaptiveColor, color.getAdaptiveColor(.light))
    }
    
    func test_theme_color_light() throws {
        // Arrange
        let color = ThemeColor(light: "#FFFFFF", dark: "#000000")
        // Act
        let adaptiveColor = color.getAdaptiveColor(.light)
        
        // Assert
        XCTAssertEqual(adaptiveColor, "#FFFFFF")
    }   
    
    func test_theme_color_dark() throws {
        // Arrange
        let color = ThemeColor(light: "#FFFFFF", dark: "#000000")
        // Act
        let adaptiveColor = color.getAdaptiveColor(.dark)
        
        // Assert
        XCTAssertEqual(adaptiveColor, "#000000")
    }    
    
    func test_theme_color_dark_default_light() throws {
        // Arrange
        let color = ThemeColor(light: "#FFFFFF", dark: nil)
        // Act
        let adaptiveColor = color.getAdaptiveColor(.dark)
        
        // Assert
        XCTAssertEqual(adaptiveColor, "#FFFFFF")
    }
        
    func test_theme_color_dark_default_empty() throws {
        // Arrange
        let color = ThemeColor(light: "", dark: nil)
        // Act
        let adaptiveColor = color.getAdaptiveColor(.dark)
        
        // Assert
        XCTAssertEqual(adaptiveColor, "")
    }
    
}
