import XCTest
@testable import Rokt_Widget

final class TestV2InitResponse: XCTestCase {

    private func decode(_ json: String) throws -> V2InitResponse {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(V2InitResponse.self, from: data)
    }

    // Mirrors the happy-path body in V2SessionsInitClientPactSpec.
    private let happyPathJSON = """
    {
        "session_id": "550e8400-e29b-41d4-a716-446655440000",
        "session_token": {
            "token": "pact-stub-session-token",
            "expires_at": 1774474053000
        },
        "feature_flags": {
            "rokt-tracking-status": true,
            "client-timeout-ms": 30000,
            "ios-sdk-log-font-happy-path": true,
            "ios-sdk-use-font-register-with-url": false,
            "mobile-sdk-use-bounding-box": false,
            "mobile-sdk-use-sdk-cache": false,
            "is-post-purchase-enabled": true,
            "minimum-post-purchase-schema": "2.3.0"
        },
        "fonts": []
    }
    """

    // MARK: - Top-level decoding

    func test_decode_happyPath_topLevelFields() throws {
        let response = try decode(happyPathJSON)
        XCTAssertEqual(response.sessionId, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(response.sessionToken.token, "pact-stub-session-token")
        XCTAssertEqual(response.sessionToken.expiresAt, 1_774_474_053_000)
        XCTAssertEqual(response.fonts, [])
    }

    // MARK: - Session token

    func test_sessionToken_expiresAtDate_convertsFromMilliseconds() {
        let token = V2SessionToken(token: "t", expiresAt: 1_774_474_053_000)
        XCTAssertEqual(token.expiresAtDate, Date(timeIntervalSince1970: 1_774_474_053))
    }

    // MARK: - Feature flag accessors

    func test_featureFlags_typedAccessors() throws {
        let flags = try decode(happyPathJSON).featureFlags
        XCTAssertEqual(flags.bool(forKey: "rokt-tracking-status"), true)
        XCTAssertEqual(flags.bool(forKey: "ios-sdk-use-font-register-with-url"), false)
        XCTAssertEqual(flags.int(forKey: "client-timeout-ms"), 30000)
        XCTAssertEqual(flags.string(forKey: "minimum-post-purchase-schema"), "2.3.0")
    }

    func test_featureFlags_accessor_typeMismatchReturnsNil() throws {
        let flags = try decode(happyPathJSON).featureFlags
        XCTAssertNil(flags.bool(forKey: "client-timeout-ms"))
        XCTAssertNil(flags.int(forKey: "rokt-tracking-status"))
        XCTAssertNil(flags.string(forKey: "is-post-purchase-enabled"))
        XCTAssertNil(flags.bool(forKey: "does-not-exist"))
    }

    // MARK: - Fonts

    func test_decode_fonts_populated() throws {
        let json = """
        {
            "session_id": "s",
            "session_token": { "token": "t", "expires_at": 1 },
            "feature_flags": {},
            "fonts": [
                {
                    "font_name": "Inter-Regular",
                    "font_url": "https://example.test/inter.woff2",
                    "font_style": "normal",
                    "font_weight": "400",
                    "font_post_script_name": "Inter-Regular"
                }
            ]
        }
        """
        let font = try XCTUnwrap(try decode(json).fonts.first)
        XCTAssertEqual(font.fontName, "Inter-Regular")
        XCTAssertEqual(font.fontURL, "https://example.test/inter.woff2")
        XCTAssertEqual(font.fontStyle, "normal")
        XCTAssertEqual(font.fontWeight, "400")
        XCTAssertEqual(font.fontPostScriptName, "Inter-Regular")
    }

    // MARK: - Resilience

    func test_decode_missingFeatureFlagsAndFonts_defaultsToEmpty() throws {
        let json = """
        {
            "session_id": "s",
            "session_token": { "token": "t", "expires_at": 1 }
        }
        """
        let response = try decode(json)
        XCTAssertTrue(response.featureFlags.flags.isEmpty)
        XCTAssertEqual(response.fonts, [])
    }

    func test_decode_missingSessionToken_throws() {
        let json = """
        { "session_id": "s", "feature_flags": {}, "fonts": [] }
        """
        XCTAssertThrowsError(try decode(json))
    }

    // MARK: - toInitFeatureFlags mapping

    func test_toInitFeatureFlags_mapsDirectBooleans() throws {
        let flags = try decode(happyPathJSON).featureFlags.toInitFeatureFlags()
        XCTAssertTrue(flags.isEnabled(.roktTrackingStatus))
        XCTAssertTrue(flags.isEnabled(.shouldLogFontHappyPath))
        XCTAssertFalse(flags.isEnabled(.shouldUseFontRegisterWithUrl))
    }

    func test_toInitFeatureFlags_mapsGenericBooleans() throws {
        let flags = try decode(happyPathJSON).featureFlags.toInitFeatureFlags()
        XCTAssertFalse(flags.isEnabled(.boundingBox))
        XCTAssertFalse(flags.isEnabled(.cacheEnabled))
        XCTAssertTrue(flags.isEnabled(.postPurchaseEnabled))
    }

    func test_toInitFeatureFlags_nonEmptySchemaString_mapsToMatchTrue() throws {
        let flags = try decode(happyPathJSON).featureFlags.toInitFeatureFlags()
        XCTAssertTrue(flags.isEnabled(.minimumPostPurchaseSchema))
        XCTAssertTrue(flags.isShoppableAdsEnabled())
    }

    func test_toInitFeatureFlags_emptySchemaString_mapsToMatchFalse() {
        let flags = V2FeatureFlags(flags: [
            "is-post-purchase-enabled": .bool(true),
            "minimum-post-purchase-schema": .string("")
        ]).toInitFeatureFlags()
        XCTAssertFalse(flags.isEnabled(.minimumPostPurchaseSchema))
        XCTAssertFalse(flags.isShoppableAdsEnabled())
    }

    func test_toInitFeatureFlags_absentRoktTrackingStatus_defaultsToTrue() {
        let flags = V2FeatureFlags(flags: [:]).toInitFeatureFlags()
        XCTAssertTrue(flags.isEnabled(.roktTrackingStatus))
    }
}
