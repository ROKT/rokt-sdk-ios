import Foundation
internal import RoktUXHelper

@objc public class RoktConfig: NSObject {
    let colorMode: ColorMode
    let cacheConfig: CacheConfig

    private init(colorMode: ColorMode,
                 cacheConfig: CacheConfig) {
        self.colorMode = colorMode
        self.cacheConfig = cacheConfig
    }

    /**
     Specifies the color mode for the application.

     - light: Application is in Light Mode.
     - dark: Application is in Dark Mode.
     - system: Application uses System Color Mode (This value is used if not specified).
     */
    @objc public enum ColorMode: Int {
        case light
        case dark
        case system
    }

    /**
     Configuration for caching of layouts in the Rokt SDK.
     */
    @objc public class CacheConfig: NSObject {
        /// The duration for which the experience should be cached, in seconds.
        let cacheDuration: TimeInterval

        /// Optional attributes used as the cache key; if nil, falls back to all attributes from Rokt.execute.
        let cacheAttributes: [String: String]?

        /// Internal flag indicating whether caching is enabled.
        internal let enableCache: Bool

        /// Maximum allowed cache duration (90 minutes).
        @objc public static let maxCacheDuration = TimeInterval(90 * 60)

        /**
         Initializes the cache configuration.

         - Parameters:
           - cacheDuration: Optional TimeInterval for which the Rokt SDK should cache the experience.
             Maximum allowed value is 90 minutes and the default (if value is not provided or invalid)
             is 90 minutes.
           - cacheAttributes: Optional attributes to be used as cache key. If null, all the attributes
             sent in Rokt.execute will be used as the cache key.
         */
        @objc public init(cacheDuration: TimeInterval = maxCacheDuration,
                          cacheAttributes: [String: String]? = nil) {
            self.cacheDuration = (cacheDuration > 0 && cacheDuration < CacheConfig.maxCacheDuration) ? cacheDuration : CacheConfig
                .maxCacheDuration
            self.cacheAttributes = cacheAttributes
            self.enableCache = true
        }

        /// Internal initializer allowing explicit control over whether caching is enabled.
        internal init(cacheDuration: TimeInterval = maxCacheDuration,
                      cacheAttributes: [String: String]? = nil,
                      enableCache: Bool) {
            self.cacheDuration = (cacheDuration > 0 && cacheDuration < CacheConfig.maxCacheDuration) ? cacheDuration : CacheConfig
                .maxCacheDuration
            self.cacheAttributes = cacheAttributes
            self.enableCache = enableCache
        }

        /// Returns the attributes for caching operations, falling back to provided attributes if none are configured.
        /// - Parameter fallbackAttributes: The full attributes to use if no cache attributes are specified.
        /// - Returns: The attributes to use for cache operations.
        func getCacheAttributesOrFallback(_ fallbackAttributes: [String: String]) -> [String: String] {
            return cacheAttributes ?? fallbackAttributes
        }

        /// Checks if caching is enabled based on the configuration.
        func isCacheEnabled() -> Bool {
            return enableCache
        }
    }

    @objc public class Builder: NSObject {
        var colorMode: ColorMode?
        var cacheConfig: CacheConfig?

        @objc public func colorMode(_ colorMode: ColorMode) -> Builder {
            self.colorMode = colorMode
            return self
        }

        @objc public func cacheConfig(_ cacheConfig: CacheConfig) -> Builder {
            self.cacheConfig = cacheConfig
            return self
        }

        @objc public func build() -> RoktConfig {
            return RoktConfig(colorMode: colorMode ?? .system,
                              cacheConfig: cacheConfig ?? CacheConfig())
        }

    }

    @available(iOS 15, *)
    func getUXConfig() -> RoktUXConfig {
        let builder = RoktUXConfig.Builder().logLevel(RoktLogger.shared.logLevel.toUXLogLevel())
        switch self.colorMode {
        case .light:
            _ = builder.colorMode(.light)
        case .dark:
            _ = builder.colorMode(.dark)
        default:
            _ = builder.colorMode(.system)
        }
        return builder.build()
    }
}
