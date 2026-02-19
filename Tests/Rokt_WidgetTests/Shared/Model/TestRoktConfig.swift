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
}
