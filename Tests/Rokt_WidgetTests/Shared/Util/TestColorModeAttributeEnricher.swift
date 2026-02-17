import XCTest
@testable import Rokt_Widget // Gives access to internal types if needed, and the SUT

// MARK: - Test Keys & Values (mirroring private keys in ColorModeAttributeEnricher)

private let BE_COLOR_MODE_KEY = "colormode"
private let LIGHT_MODE_STRING = "LIGHT"
private let DARK_MODE_STRING = "DARK"

// MARK: - Mock SystemUserInterfaceStyleProvider

private class MockSystemUserInterfaceStyleProvider: SystemUserInterfaceStyleProvider {
    var mockCurrentStyle: UIUserInterfaceStyle = .unspecified // Default to unspecified or light
    var currentStyle: UIUserInterfaceStyle { return mockCurrentStyle }
}

// MARK: - Test Class

class TestColorModeAttributeEnricher: XCTestCase {

    private var sut: ColorModeAttributeEnricher!

    func testEnrich_whenIOS13AndNoConfig_systemLight_returnsLightMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider()
        mockStyleProvider.mockCurrentStyle = .light
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)

        // When
        let attributes = sut.enrich(config: nil)

        // Then
        XCTAssertEqual(attributes[BE_COLOR_MODE_KEY], LIGHT_MODE_STRING)
    }

    func testEnrich_whenIOS13AndNoConfig_systemDark_returnsDarkMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider()
        mockStyleProvider.mockCurrentStyle = .dark
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)

        // When
        let attributes = sut.enrich(config: nil)

        // Then
        XCTAssertEqual(attributes[BE_COLOR_MODE_KEY], DARK_MODE_STRING)
    }

    func testEnrich_whenIOS13AndConfigLight_returnsLightMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider() // Style provider still needed for init
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)
        let roktConfig = RoktConfig.Builder().colorMode(.light).build()

        // When
        let attributes = sut.enrich(config: roktConfig)

        // Then
        XCTAssertEqual(attributes[BE_COLOR_MODE_KEY], LIGHT_MODE_STRING)
    }

    func testEnrich_whenIOS13AndConfigDark_returnsDarkMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider()
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)
        let roktConfig = RoktConfig.Builder().colorMode(.dark).build()

        // When
        let attributes = sut.enrich(config: roktConfig)

        // Then
        XCTAssertEqual(attributes[BE_COLOR_MODE_KEY], DARK_MODE_STRING)
    }

    func testEnrich_whenIOS13AndConfigSystem_systemLight_returnsLightMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider()
        mockStyleProvider.mockCurrentStyle = .light
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)
        let roktConfig = RoktConfig.Builder().colorMode(.system).build()

        // When
        let attributes = sut.enrich(config: roktConfig)

        // Then
        XCTAssertEqual(attributes[BE_COLOR_MODE_KEY], LIGHT_MODE_STRING)
    }

    func testEnrich_whenIOS13AndConfigSystem_systemDark_returnsDarkMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider()
        mockStyleProvider.mockCurrentStyle = .dark
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)
        let roktConfig = RoktConfig.Builder().colorMode(.system).build()

        // When
        let attributes = sut.enrich(config: roktConfig)

        // Then
        XCTAssertEqual(attributes[BE_COLOR_MODE_KEY], DARK_MODE_STRING)
    }

    func testEnrich_whenIOS13AndNoConfig_systemUnspecified_returnsLightMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider()
        mockStyleProvider.mockCurrentStyle = .unspecified // Test the .unspecified case
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)

        // When
        let attributes = sut.enrich(config: nil)

        // Then
        XCTAssertEqual(
            attributes[BE_COLOR_MODE_KEY],
            LIGHT_MODE_STRING,
            "Unspecified system style should default to LIGHT"
        )
    }

    func testEnrich_whenIOS13AndConfigSystem_systemUnspecified_returnsLightMode() {
        // Given
        let mockStyleProvider = MockSystemUserInterfaceStyleProvider()
        mockStyleProvider.mockCurrentStyle = .unspecified
        sut = ColorModeAttributeEnricher(styleProvider: mockStyleProvider)
        let roktConfig = RoktConfig.Builder().colorMode(.system).build()

        // When
        let attributes = sut.enrich(config: roktConfig)

        // Then
        XCTAssertEqual(
            attributes[BE_COLOR_MODE_KEY],
            LIGHT_MODE_STRING,
            "System config with unspecified system style should default to LIGHT"
        )
    }
}
