import XCTest
@testable import Rokt_Widget

final class TestRoktConfig: XCTestCase {

    private let defaultMaxCacheDuration = TimeInterval(90 * 60)

    func test_cacheConfig_withEmptyCacheDuration_usesDefault() {
        // Arrange
        let cacheConfig = RoktConfig.CacheConfig()

        // Act
        let cacheDuration = cacheConfig.cacheDuration

        // Assert
        XCTAssertEqual(cacheDuration, defaultMaxCacheDuration)
    }

    func test_cacheConfig_withCacheDurationOverMax_usesDefault() {
        // Arrange
        let cacheConfig = RoktConfig.CacheConfig(cacheDuration: TimeInterval(100 * 60))

        // Act
        let cacheDuration = cacheConfig.cacheDuration

        // Assert
        XCTAssertEqual(cacheDuration, defaultMaxCacheDuration)
    }

    func test_cacheConfig_withValidCacheDuration_usesValidCacheDuration() {
        // Arrange
        let cacheConfig = RoktConfig.CacheConfig(cacheDuration: TimeInterval(10 * 60))

        // Act
        let cacheDuration = cacheConfig.cacheDuration

        // Assert
        XCTAssertEqual(cacheDuration, TimeInterval(10 * 60))
    }

    // MARK: - CacheConfig enableCache

    func test_cacheConfig_publicInit_enablesCacheByDefault() {
        // Arrange
        let cacheConfig = RoktConfig.CacheConfig()

        // Act & Assert
        XCTAssertTrue(cacheConfig.isCacheEnabled())
    }

    func test_cacheConfig_internalInit_withEnableCacheFalse_disablesCache() {
        // Arrange
        let cacheConfig = RoktConfig.CacheConfig(enableCache: false)

        // Act & Assert
        XCTAssertFalse(cacheConfig.isCacheEnabled())
    }

    func test_cacheConfig_internalInit_withEnableCacheTrue_enablesCache() {
        // Arrange
        let cacheConfig = RoktConfig.CacheConfig(enableCache: true)

        // Act & Assert
        XCTAssertTrue(cacheConfig.isCacheEnabled())
    }

    // MARK: - Builder defaults

    func test_builder_withoutCacheConfig_disablesCacheByDefault() {
        // Arrange & Act
        let config = RoktConfig.Builder().build()

        // Assert
        XCTAssertFalse(config.cacheConfig.isCacheEnabled())
    }

    func test_builder_withoutCacheConfig_usesSystemColorMode() {
        // Arrange & Act
        let config = RoktConfig.Builder().build()

        // Assert
        XCTAssertEqual(config.colorMode, .system)
    }

    func test_builder_withColorModeOnly_disablesCacheByDefault() {
        // Arrange & Act
        let config = RoktConfig.Builder()
            .colorMode(.light)
            .build()

        // Assert
        XCTAssertEqual(config.colorMode, .light)
        XCTAssertFalse(config.cacheConfig.isCacheEnabled())
    }

    func test_builder_withExplicitCacheConfig_enablesCache() {
        // Arrange & Act
        let config = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig())
            .build()

        // Assert
        XCTAssertTrue(config.cacheConfig.isCacheEnabled())
        XCTAssertEqual(config.cacheConfig.cacheDuration, defaultMaxCacheDuration)
    }

    func test_builder_withCacheConfigAndColorMode_preservesBoth() {
        // Arrange & Act
        let config = RoktConfig.Builder()
            .colorMode(.dark)
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: TimeInterval(10 * 60)))
            .build()

        // Assert
        XCTAssertEqual(config.colorMode, .dark)
        XCTAssertTrue(config.cacheConfig.isCacheEnabled())
        XCTAssertEqual(config.cacheConfig.cacheDuration, TimeInterval(10 * 60))
    }

    // MARK: - getCacheAttributesOrFallback

    func test_cacheConfig_getCacheAttributesOrFallback_withNilCacheAttributes_returnsFallback() {
        // Arrange
        let cacheConfig = RoktConfig.CacheConfig()
        let fallback = ["email": "test@rokt.com"]

        // Act
        let result = cacheConfig.getCacheAttributesOrFallback(fallback)

        // Assert
        XCTAssertEqual(result, fallback)
    }

    func test_cacheConfig_getCacheAttributesOrFallback_withCacheAttributes_returnsCacheAttributes() {
        // Arrange
        let cacheAttributes = ["country": "US"]
        let cacheConfig = RoktConfig.CacheConfig(cacheAttributes: cacheAttributes)
        let fallback = ["email": "test@rokt.com"]

        // Act
        let result = cacheConfig.getCacheAttributesOrFallback(fallback)

        // Assert
        XCTAssertEqual(result, cacheAttributes)
    }
}
