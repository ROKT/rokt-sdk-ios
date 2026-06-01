import XCTest
@testable import RoktUXHelper

final class TestCreativeImageAccessibility: XCTestCase {

    func test_accessibilityAltText_returnsNil_forEmptyOrGenericBackendValues() {
        let genericAlts = [
            "image",
            "Image",
            " IMAGE ",
            "img",
            "photo",
            "picture",
            "1.91:1 Image",
            "Transparent 1.91:1 Image",
            "Logo Image",
            "1.91:1 Logo Image",
            "Transparent 1.91:1 Logo Image",
            "Transparent Logo Image",
            "Transparent Image",
            "",
            "   ",
            nil
        ]
        for alt in genericAlts {
            let image = CreativeImage(light: "https://example.com/a.png", dark: nil, alt: alt, title: "image")
            XCTAssertNil(image.accessibilityAltText, "Expected nil for alt: \(String(describing: alt))")
        }
    }

    func test_accessibilityAltText_returnsTrimmedValue_forDescriptiveAlt() {
        let image = CreativeImage(
            light: "https://example.com/a.png",
            dark: nil,
            alt: "  Acme rewards logo  ",
            title: nil
        )
        XCTAssertEqual(image.accessibilityAltText, "Acme rewards logo")
    }
}
