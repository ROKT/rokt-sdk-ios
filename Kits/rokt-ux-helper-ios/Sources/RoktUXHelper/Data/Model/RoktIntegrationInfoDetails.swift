import Foundation
import UIKit

private enum Constants {
    static let framework: String = "Swift"
    static let kBundleShort: String = "CFBundleShortVersionString"
    static let layoutSchemaVersion: String = "2.7.0"
    static let name: String = "UX Helper iOS"
    static let platform: String = "iOS"
    static let version: String = "0.1.0"
}

public struct RoktIntegrationInfo: Encodable {
    static var shared: RoktIntegrationInfo = .init(integration: .init())

    public let integration: RoktIntegrationInfoDetails

    /// Method to convert SDK info to a JSON string
    public var jsonString: String {
        guard let jsonData = try? JSONEncoder().encode(self),
              let string = String(data: jsonData, encoding: .utf8) else { return "" }
        return string
    }

    /// Method to convert SDK info to a JSON dictionary
    public var json: [String: Any] {
        (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self))) as? [String: Any] ?? [:]
    }
}

public struct RoktIntegrationInfoDetails: Codable {
    public let deviceType: String
    public let deviceModel: String
    public let deviceLocale: String
    public let framework: String
    public let layoutSchemaVersion: String
    public let name: String
    public let version: String
    public let operatingSystem: String
    public let operatingSystemVersion: String
    public let packageVersion: String?
    public let packageName: String?
    public let platform: String

    init(
        deviceType: String = UIDevice.current.userInterfaceIdiom.string,
        deviceModel: String = UIDevice.modelName,
        deviceLocale: String = Locale.current.identifier,
        framework: String = Constants.framework,
        layoutSchemaVersion: String = Constants.layoutSchemaVersion,
        name: String = Constants.name,
        operatingSystem: String = UIDevice.current.systemName,
        operatingSystemVersion: String = UIDevice.current.systemVersion,
        platform: String = UIDevice.current.systemName,
        packageVersion: String? = Bundle.main.infoDictionary?[Constants.kBundleShort] as? String,
        packageName: String? = Bundle.main.bundleIdentifier,
        version: String = Constants.version
    ) {
        self.deviceType = deviceType
        self.deviceModel = deviceModel
        self.deviceLocale = deviceLocale
        self.framework = framework
        self.layoutSchemaVersion = layoutSchemaVersion
        self.name = name
        self.operatingSystem = operatingSystem
        self.operatingSystemVersion = operatingSystemVersion
        self.platform = platform
        self.packageVersion = packageVersion
        self.packageName = packageName
        self.version = version
    }
}

private extension UIUserInterfaceIdiom {
    var string: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .phone:
            "Phone"
        case .pad:
            "Tablet"
        case .tv:
            "TV"
        case .carPlay:
            "CarPlay"
        case .mac:
            "Mac"
        case .vision:
            "Vision"
        @unknown default:
            "unknown"
        }
    }
}
