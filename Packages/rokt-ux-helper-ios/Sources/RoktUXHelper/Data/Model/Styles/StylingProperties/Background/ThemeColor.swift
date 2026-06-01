import SwiftUI
import DcuiSchema

@available(iOS 13, *)
extension ThemeColor {
    func getAdaptiveColor(_ colorScheme: ColorScheme) -> String {
        switch colorScheme {
        case .light:
            return light
        case .dark:
            // if phone is in darkmode and dark color is nil, return light as default
            return dark ?? light
        default:
            return light
        }
    }
}

@available(iOS 13, *)
extension UITraitCollection {
    static func getConfigColorSchema(colorMode: RoktUXConfig.ColorMode?) -> ColorScheme {
        switch colorMode {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
    }
}
