import AppTrackingTransparency
import Foundation

private let BE_APPLE_TRACKING_CONSENT_KEY = "rokt.nativemobile.apple_tracking_consent"

/// Enriches experience requests with the device's App Tracking Transparency status.
///
/// The value is the raw `ATTrackingManager.AuthorizationStatus` (`0` not determined,
/// `1` restricted, `2` denied, `3` authorized), read on every request so it reflects the
/// user's current choice. It replaces any partner-supplied value under the same key.
class TrackingConsentAttributeEnricher: AttributeEnricher {
    private let statusProvider: () -> UInt

    init(statusProvider: @escaping () -> UInt = { ATTrackingManager.trackingAuthorizationStatus.rawValue }) {
        self.statusProvider = statusProvider
    }

    func enrich(config: RoktConfig?) -> [String: String] {
        [BE_APPLE_TRACKING_CONSENT_KEY: String(statusProvider())]
    }
}
