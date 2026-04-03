import UIKit

private let BE_COLOR_MODE_KEY = "colormode"
private let LIGHT_MODE_STRING = "LIGHT"
private let DARK_MODE_STRING = "DARK"

// MARK: - SystemUserInterfaceStyleProvider Protocol and Default Implementation

protocol SystemUserInterfaceStyleProvider {
    var currentStyle: UIUserInterfaceStyle { get }
}

class DefaultSystemUserInterfaceStyleProvider: SystemUserInterfaceStyleProvider {
    var currentStyle: UIUserInterfaceStyle {
        return UIScreen.main.traitCollection.userInterfaceStyle
    }
}

// MARK: - ColorModeAttributeEnricher

class ColorModeAttributeEnricher: AttributeEnricher {

    private let styleProvider: SystemUserInterfaceStyleProvider

    // Default initializer
    init() {
        self.styleProvider = DefaultSystemUserInterfaceStyleProvider()
    }

    // Internal initializer for dependency injection (primarily for testing)
    internal init(styleProvider: SystemUserInterfaceStyleProvider = DefaultSystemUserInterfaceStyleProvider()) {
        self.styleProvider = styleProvider
    }

    func enrich(config: RoktConfig?) -> [String: String] {
        var attributes = [String: String]()
        attributes = appendColorMode(config: config)
        return attributes
    }

    private func appendColorMode(config: RoktConfig?) -> [String: String] {
        var mutablePayload = [String: String]()

        if let config = config {
            switch config.colorMode {
            case .light:
                mutablePayload[BE_COLOR_MODE_KEY] = getColorModeInternal(screenColorMode: .light)
            case .dark:
                mutablePayload[BE_COLOR_MODE_KEY] = getColorModeInternal(screenColorMode: .dark)
            case .system:
                mutablePayload[BE_COLOR_MODE_KEY] = getColorModeInternal()
            }
        } else {
            mutablePayload[BE_COLOR_MODE_KEY] = getColorModeInternal()
        }
        return mutablePayload
    }

    /// Internal version of getColorMode that takes the provider
    private func getColorModeInternal(
        screenColorMode: UIUserInterfaceStyle? = nil
    ) -> String {
        let styleToConsider = screenColorMode ?? styleProvider.currentStyle

        var colorModeText: String
        switch styleToConsider {
        case .dark:
            colorModeText = DARK_MODE_STRING
        case .light, .unspecified:
            colorModeText = LIGHT_MODE_STRING
        @unknown default:
            colorModeText = LIGHT_MODE_STRING
        }
        return colorModeText
    }
}
