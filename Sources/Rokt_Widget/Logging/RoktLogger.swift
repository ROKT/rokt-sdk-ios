import Foundation

/// Thread-safe logger for Rokt SDK with configurable log levels.
///
/// Use `RoktLogger.shared` to access the singleton instance.
/// Set the log level via `Rokt.setLogLevel(_:)` for unified propagation to UX Helper.
///
/// Example:
/// ```swift
/// Rokt.setLogLevel(.debug)
/// RoktLogger.shared.debug("SDK initialized")
/// ```
final class RoktLogger: @unchecked Sendable {
    /// Shared singleton instance
    private(set) static var shared = RoktLogger()

    /// Replaces the shared instance. Primarily for testing.
    /// - Parameter logger: The logger instance to use as shared
    /// - Returns: The previous shared instance for restoration
    @discardableResult
    internal static func setShared(_ logger: RoktLogger) -> RoktLogger {
        let previous = shared
        shared = logger
        return previous
    }

    private let lock = NSLock()
    private var _logLevel: RoktLogLevel = .none

    /// The current log level. Messages below this level will not be logged.
    /// Default is `.none` (no logging).
    ///
    /// Note: Setting this directly does NOT propagate to UX Helper.
    /// Use `Rokt.setLogLevel(_:)` for unified log level propagation.
    var logLevel: RoktLogLevel {
        get { lock.withLock { _logLevel } }
        set { lock.withLock { _logLevel = newValue } }
    }

    /// Logs a verbose message for detailed diagnostic information.
    /// Includes file, function, and line information for tracing.
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error to include
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func verbose(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.verbose, message, error, file: file, function: function, line: line)
    }

    /// Logs a debug message for development-time information.
    /// Includes file, function, and line information for tracing.
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error to include
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func debug(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, message, error, file: file, function: function, line: line)
    }

    /// Logs an info message for general operational events.
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error to include
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func info(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message, error, file: file, function: function, line: line)
    }

    /// Logs a warning message for recoverable issues.
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error to include
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func warning(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, message, error, file: file, function: function, line: line)
    }

    /// Logs an error message for failures that prevent expected behavior.
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error to include
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message, error, file: file, function: function, line: line)
    }

    private func log(
        _ level: RoktLogLevel,
        _ message: String,
        _ error: Error?,
        file: String,
        function: String,
        line: Int
    ) {
        guard level >= logLevel, logLevel != .none else { return }
        let prefix = "[Rokt/\(level.label)]"
        let fname = (file as NSString).lastPathComponent
        let errorSuffix = error.map { " | Error: \($0.localizedDescription)" } ?? ""
        print("\(prefix) [\(fname) \(function):\(line)] \(message)\(errorSuffix)")
    }
}
