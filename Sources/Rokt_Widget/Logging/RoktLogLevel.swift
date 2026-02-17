import Foundation
internal import RoktUXHelper

/// Log levels for Rokt SDK, ordered from most to least verbose.
///
/// Use these levels to control the verbosity of console logging output:
/// - `verbose`: Detailed diagnostic information for deep debugging
/// - `debug`: Development-time information like state changes
/// - `info`: General operational events
/// - `warning`: Recoverable issues that don't prevent operation
/// - `error`: Failures that prevent expected behavior
/// - `none`: No logging (default for production)
@objc public enum RoktLogLevel: Int, Comparable, Sendable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case none = 5

    public static func < (lhs: RoktLogLevel, rhs: RoktLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .none: return "NONE"
        }
    }

    @available(iOS 15, *)
    func toUXLogLevel() -> RoktUXLogLevel {
        RoktUXLogLevel(rawValue: self.rawValue) ?? .none
    }
}
