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

    private func getFeatureFlag(_ features: [String: FeatureFlagItem]) -> InitFeatureFlags {
        return InitFeatureFlags(roktTrackingStatus: true,
                                shouldLogFontHappyPath: false,
                                shouldUseFontRegisterWithUrl: false,
                                featureFlags: features)
    }
}
