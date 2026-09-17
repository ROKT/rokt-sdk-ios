import Foundation

/// Configuration for an unattended run of the sample app, supplied entirely at launch so an
/// agent, a UI test or a CI job can drive it without touching the pickers.
///
/// Read from `UserDefaults` — which is where `XCUIApplication.launchArguments` of the form
/// `-key value` land — with a `ROKT_*` environment-variable fallback for plain
/// `xcrun simctl launch` use. No value is committed: accounts and page identifiers are the
/// caller's to supply.
struct AutomationLaunchConfig {

    enum Key: String, CaseIterable {
        case autoRun = "roktAutoRun"
        case tagId = "roktTagId"
        case environment = "roktEnvironment"
        case pageIdentifier = "roktPageIdentifier"
        case location = "roktLocation"
        case attributes = "roktAttributes"

        /// `-roktTagId` as a launch argument, `ROKT_TAG_ID` as an environment variable.
        var environmentVariableName: String {
            let withoutPrefix = rawValue.dropFirst("rokt".count)
            let snakeCased = withoutPrefix.reduce(into: "") { result, character in
                if character.isUppercase, !result.isEmpty { result.append("_") }
                result.append(character)
            }
            return "ROKT_" + snakeCased.uppercased()
        }
    }

    /// Drive the placement flow without waiting for a tap.
    let isAutoRunEnabled: Bool
    let tagId: String?
    /// Left `nil` deliberately reads as "don't call `Rokt.setEnvironment`", which keeps the
    /// build configuration's own environment — the only way to reach the offline Mock
    /// transports, since `setEnvironment` replaces the configuration wholesale.
    let environment: Environment?
    let pageIdentifier: String?
    let location: String?
    let attributes: [String: String]

    static var current: AutomationLaunchConfig { AutomationLaunchConfig() }

    init(
        defaults: UserDefaults = .standard,
        processInfo: ProcessInfo = .processInfo
    ) {
        func value(_ key: Key) -> String? {
            if let fromArguments = defaults.string(forKey: key.rawValue),
               !fromArguments.isEmpty {
                return fromArguments
            }
            let fromEnvironment = processInfo.environment[key.environmentVariableName]
            return (fromEnvironment?.isEmpty == false) ? fromEnvironment : nil
        }

        isAutoRunEnabled = value(.autoRun).map { ["1", "true", "YES", "yes"].contains($0) } ?? false
        tagId = value(.tagId)
        pageIdentifier = value(.pageIdentifier)
        location = value(.location)
        environment = value(.environment).flatMap(Environment.init(rawValue:))
        attributes = Self.parseAttributes(value(.attributes))
    }

    /// A JSON object of string values, so a caller can pass the attributes a page needs without
    /// a rebuild. Malformed input is dropped rather than crashing an unattended run.
    private static func parseAttributes(_ raw: String?) -> [String: String] {
        guard let data = raw?.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }

        return parsed.compactMapValues { element in
            switch element {
            case let string as String: return string
            case let number as NSNumber: return number.stringValue
            default: return nil
            }
        }
    }
}
