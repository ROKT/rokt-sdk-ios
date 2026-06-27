import XCTest
@testable import Rokt_Widget

final class TestInitResponseAdapter: XCTestCase {

    private func response(
        flags: [String: FeatureFlagValue],
        fonts: [FontItem] = []
    ) -> InitResponse {
        InitResponse(
            sessionId: "sess",
            sessionToken: SessionToken(token: "jwt", expiresAt: 1),
            featureFlags: FeatureFlags(flags: flags),
            fonts: fonts
        )
    }

    func test_toInitRespose_extractsClientTimeoutFromFeatureFlags() {
        let response = response(flags: ["client-timeout-ms": .int(30000)])

        let result = response.toInitRespose(featureFlags: InitFeatureFlags())

        XCTAssertEqual(result.timeout, 30000)
    }

    func test_toInitRespose_missingClientTimeout_isZeroSoCallerKeepsDefault() {
        let result = response(flags: [:]).toInitRespose(featureFlags: InitFeatureFlags())

        XCTAssertEqual(result.timeout, 0)
    }

    func test_toInitRespose_doesNotCarryDelayOrSessionTimeout() {
        let result = response(flags: ["client-timeout-ms": .int(8000)])
            .toInitRespose(featureFlags: InitFeatureFlags())

        XCTAssertEqual(result.delay, 0)
        XCTAssertNil(result.clientSessionTimeout)
    }

    func test_toInitRespose_mapsFonts() {
        let fonts = [
            FontItem(
                fontName: "Arial",
                fontURL: "https://example.com/arial.ttf",
                fontStyle: "italic",
                fontWeight: "700",
                fontPostScriptName: "Arial-Italic"
            ),
            FontItem(
                fontName: "Roboto",
                fontURL: "https://example.com/roboto.ttf",
                fontStyle: nil,
                fontWeight: nil,
                fontPostScriptName: nil
            )
        ]

        let result = response(flags: [:], fonts: fonts).toInitRespose(featureFlags: InitFeatureFlags())

        XCTAssertEqual(result.fonts.count, 2)
        XCTAssertEqual(result.fonts[0].name, "Arial")
        XCTAssertEqual(result.fonts[0].url, "https://example.com/arial.ttf")
        XCTAssertEqual(result.fonts[0].postScriptName, "Arial-Italic")
        XCTAssertEqual(result.fonts[1].name, "Roboto")
        XCTAssertNil(result.fonts[1].postScriptName)
    }

    func test_toInitRespose_passesThroughBridgedFeatureFlags() {
        let bridged = InitFeatureFlags(roktTrackingStatus: true)

        let result = response(flags: [:]).toInitRespose(featureFlags: bridged)

        XCTAssertTrue(result.featureFlags.isEnabled(.roktTrackingStatus))
    }
}
