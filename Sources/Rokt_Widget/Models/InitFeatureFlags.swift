import Foundation

struct InitFeatureFlags {
    enum FeatureFlagType: String {
        case roktTrackingStatus
        case shouldLogFontHappyPath
        case shouldUseFontRegisterWithUrl
        case boundingBox = "mobile-sdk-use-bounding-box"
        case cacheEnabled = "mobile-sdk-use-sdk-cache"
        case temporaryFontCache = "mobile-sdk-use-temporary-font-cache"
        case realTimeEvents = "mobile-sdk-real-time-events"
    }

    private let roktTrackingStatus: Bool
    private let shouldLogFontHappyPath: Bool
    private let shouldUseFontRegisterWithUrl: Bool

    private let featureFlags: [String: FeatureFlagItem]

    init(
        roktTrackingStatus: Bool = false,
        shouldLogFontHappyPath: Bool = false,
        shouldUseFontRegisterWithUrl: Bool = false,
        featureFlags: [String: FeatureFlagItem] = [:]
    ) {
        self.roktTrackingStatus = roktTrackingStatus
        self.shouldLogFontHappyPath = shouldLogFontHappyPath
        self.shouldUseFontRegisterWithUrl = shouldUseFontRegisterWithUrl
        self.featureFlags = featureFlags
    }

    func isEnabled(_ featureFlag: FeatureFlagType) -> Bool {
        switch featureFlag {
        case .roktTrackingStatus:
            return roktTrackingStatus
        case .shouldLogFontHappyPath:
            return shouldLogFontHappyPath
        case .shouldUseFontRegisterWithUrl:
            return shouldUseFontRegisterWithUrl
        default:
            return featureFlags[featureFlag.rawValue]?.match ?? false
        }
    }
}
