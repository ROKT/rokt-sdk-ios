import XCTest
@testable import Rokt_Widget

// Mirrors the private key in TrackingConsentAttributeEnricher.
private let BE_APPLE_TRACKING_CONSENT_KEY = "rokt.nativemobile.apple_tracking_consent"

class TestTrackingConsentAttributeEnricher: XCTestCase {

    func testEnrich_reportsRawAuthorizationStatus() {
        let sut = TrackingConsentAttributeEnricher(statusProvider: { 2 })

        XCTAssertEqual(sut.enrich(config: nil), [BE_APPLE_TRACKING_CONSENT_KEY: "2"])
    }
}
