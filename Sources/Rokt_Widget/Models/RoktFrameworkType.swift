import Foundation

/// Rokt public framework type enum
@objc public enum RoktFrameworkType: Int {
    case iOS
    case Cordova
    case ReactNative
    case Flutter
    case Maui

    // `objc` enums have to be `Int` types. this maps types to meaningful text
    var toString: String {
        switch self {
        case .iOS:
            return "iOS"
        case .Cordova:
            return "cordova"
        case .ReactNative:
            return "reactNative"
        case .Flutter:
            return "flutter"
        case .Maui:
            return "maui"
        default:
            return "iOS"
        }
    }
}
