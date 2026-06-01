import Foundation

/// Configuration class for Rokt UX.
public struct RoktUXConfig {
    /// The color mode for the UX.
    let colorMode: ColorMode
    /// Optional image loader for the UX.
    let imageLoader: RoktUXImageLoader?
    /// The log level for this configuration instance.
    let logLevel: RoktUXLogLevel

    private init(
        colorMode: ColorMode,
        imageLoader: RoktUXImageLoader?,
        logLevel: RoktUXLogLevel
    ) {
        self.colorMode = colorMode
        self.imageLoader = imageLoader
        self.logLevel = logLevel
    }

    /// Enum representing the color modes available.
    public enum ColorMode: Int {
        /// Application is in Light Mode.
        case light
        /// Application is in Dark Mode.
        case dark
        /// Application defaults to System Color Mode.
        case system
    }

    /// Builder class for constructing `RoktUXConfig`
    public class Builder: NSObject {
        var colorMode: ColorMode?
        weak var imageLoader: RoktUXImageLoader?
        var logLevel: RoktUXLogLevel?

        /// Sets the color mode for the configuration.
        /// - Parameter colorMode: The color mode to be set.
        /// - Returns: The builder instance for chaining.
        public func colorMode(_ colorMode: ColorMode) -> Builder {
            self.colorMode = colorMode
            return self
        }

        /// Sets the image loader for the configuration.
        /// - Parameter imageLoader: The image loader to be set.
        /// - Returns: The builder instance for chaining.
        public func imageLoader(_ imageLoader: RoktUXImageLoader) -> Builder {
            self.imageLoader = imageLoader
            return self
        }

        /// Enables or disables debug logging for the RoktUXConfig.
        /// - Parameter enable: A Boolean value indicating whether debug logging should be enabled.
        /// - Returns: The Builder instance with the updated logging configuration.
        @available(*, deprecated, message: "Use logLevel(_:) instead")
        public func enableLogging(_ enable: Bool) -> Builder {
            self.logLevel = enable ? .debug : RoktUXLogLevel.none
            return self
        }

        /// Sets the log level for the RoktUXConfig.
        /// - Parameter logLevel: The log level to be set.
        /// - Returns: The Builder instance with the updated log level configuration.
        public func logLevel(_ logLevel: RoktUXLogLevel) -> Builder {
            self.logLevel = logLevel
            return self
        }

        /// Builds the `RoktUXConfig` instance with the specified settings.
        /// - Returns: A configured `RoktUXConfig` instance.
        public func build() -> RoktUXConfig {
            RoktUXConfig(
                colorMode: colorMode ?? .system,
                imageLoader: imageLoader,
                logLevel: logLevel ?? .none
            )
        }
    }
}
