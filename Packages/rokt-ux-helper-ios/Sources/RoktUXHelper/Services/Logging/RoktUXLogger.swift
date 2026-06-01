import Foundation

/// Thread-safe logger for RoktUXHelper with configurable log levels.
///
/// Use `RoktUXLogger.shared` to access the singleton instance.
/// Set the log level via `RoktUX.setLogLevel(_:)` or directly on the shared instance.
///
/// Example:
/// ```swift
/// RoktUXLogger.shared.logLevel = .debug
/// RoktUXLogger.shared.debug("Layout loaded")
/// ```
public final class RoktUXLogger: @unchecked Sendable {
    /// Shared singleton instance
    public private(set) static var shared = RoktUXLogger()

    /// Replaces the shared instance. Primarily for testing.
    /// - Parameter logger: The logger instance to use as shared
    /// - Returns: The previous shared instance for restoration
    @discardableResult
    internal static func setShared(_ logger: RoktUXLogger) -> RoktUXLogger {
        let previous = shared
        shared = logger
        return previous
    }

    private let lock = NSLock()
    private var _logLevel: RoktUXLogLevel = .none

    /// The current log level. Messages below this level will not be logged.
    /// Default is `.none` (no logging).
    public var logLevel: RoktUXLogLevel {
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
    public func verbose(
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
    public func debug(
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
    public func info(
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
    public func warning(
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
    public func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message, error, file: file, function: function, line: line)
    }

    private func log(
        _ level: RoktUXLogLevel,
        _ message: String,
        _ error: Error?,
        file: String,
        function: String,
        line: Int
    ) {
        guard level >= logLevel, logLevel != .none else { return }
        let prefix = "[RoktUX/\(level.label)]"
        let fname = (file as NSString).lastPathComponent
        let errorSuffix = error.map { " | Error: \($0.localizedDescription)" } ?? ""
        print("\(prefix) [\(fname) \(function):\(line)] \(message)\(errorSuffix)")
    }
}
