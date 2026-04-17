import XCTest
@testable import Rokt_Widget

final class TestInitFeatureFlags: XCTestCase {

    func test_default_init_feature_flag_is_off() {
        // Arrange
        let featureFlags = ["test": FeatureFlagItem(match: true)]

        // Act
        let isEnabled = getFeatureFlag(featureFlags).isEnabled(.temporaryFontCache)

        // Assert
        XCTAssertFalse(isEnabled)
    }

    func test__init_feature_flag_is_off() {
        // Arrange
        let featureFlags = ["mobile-sdk-use-temporary-font-cache": FeatureFlagItem(match: false)]

        // Act
        let isEnabled = getFeatureFlag(featureFlags).isEnabled(.temporaryFontCache)

        // Assert
        XCTAssertFalse(isEnabled)
    }

    func test__init_feature_flag_is_on() {
        // Arrange
        let featureFlags = ["mobile-sdk-use-temporary-font-cache": FeatureFlagItem(match: true)]

        // Act
        let isEnabled = getFeatureFlag(featureFlags).isEnabled(.temporaryFontCache)

        // Assert
        XCTAssertTrue(isEnabled)
    }

    // MARK: - isShoppableAdsEnabled

    func test_isShoppableAdsEnabled_is_false_when_both_flags_missing() {
        // Arrange
        let flags = getFeatureFlag([:])

        // Act / Assert
        XCTAssertFalse(flags.isShoppableAdsEnabled())
    }

    func test_isShoppableAdsEnabled_is_false_when_post_purchase_disabled() {
        // Arrange
        let flags = getFeatureFlag([
            "is-post-purchase-enabled": FeatureFlagItem(match: false),
            "minimum-post-purchase-schema": FeatureFlagItem(match: true)
        ])

        // Act / Assert
        XCTAssertFalse(flags.isShoppableAdsEnabled())
    }

    func test_isShoppableAdsEnabled_is_false_when_schema_disabled() {
        // Arrange
        let flags = getFeatureFlag([
            "is-post-purchase-enabled": FeatureFlagItem(match: true),
            "minimum-post-purchase-schema": FeatureFlagItem(match: false)
        ])

        // Act / Assert
        XCTAssertFalse(flags.isShoppableAdsEnabled())
    }

    func test_isShoppableAdsEnabled_is_false_when_schema_missing() {
        // Arrange
        let flags = getFeatureFlag([
            "is-post-purchase-enabled": FeatureFlagItem(match: true)
        ])

        // Act / Assert
        XCTAssertFalse(flags.isShoppableAdsEnabled())
    }

    func test_isShoppableAdsEnabled_is_true_when_both_flags_on() {
        // Arrange
        let flags = getFeatureFlag([
            "is-post-purchase-enabled": FeatureFlagItem(match: true),
            "minimum-post-purchase-schema": FeatureFlagItem(match: true)
        ])

        // Act / Assert
        XCTAssertTrue(flags.isShoppableAdsEnabled())
    }

    private func getFeatureFlag(_ features: [String: FeatureFlagItem]) -> InitFeatureFlags {
        return InitFeatureFlags(roktTrackingStatus: true,
                                shouldLogFontHappyPath: false,
                                shouldUseFontRegisterWithUrl: false,
                                featureFlags: features)
    }
}
