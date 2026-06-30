import XCTest
import PactSwift
@testable import Rokt_Widget

/// Consumer-driven pact spec for the config-only `GET /v2/init`.
class TxnInitClientPactSpec: XCTestCase {
    static var mockService: MockService!

    override class func setUp() {
        super.setUp()
        // PACT_OUTPUT_DIR redirects the JSON to a host path CI can read after the
        // simulator exits; without it PactSwift writes into the sim data container.
        let outputPath = ProcessInfo.processInfo.environment["PACT_OUTPUT_DIR"] ?? "pacts"
        let outputDir = URL(fileURLWithPath: outputPath, isDirectory: true)
        mockService = MockService(
            consumer: "rokt-sdk-ios",
            provider: "transactions-api",
            writePactTo: outputDir
        )
    }

    func test_initHappyPath_returnsFeatureFlags() {
        Self.mockService
            .uponReceiving("a v2 config request from rokt-sdk-ios returns feature flags and fonts")
            .given(ProviderState(description: "a valid config request is submitted", params: [:]))
            // Body-less GET: inputs as headers, no Authorization (cacheable).
            .withRequest(
                method: .GET,
                path: "/v2/init",
                headers: [
                    "rokt-account-id": Matcher.RegexLike("account-456", term: #".+"#),
                    "rokt-os-type": "ios",
                    "rokt-sdk-version": Matcher.SomethingLike("5.2.2"),
                    "rokt-layout-schema-version": Matcher.SomethingLike("2.1.0"),
                    "x-request-id": Matcher.RegexLike("request-id-123", term: #".+"#)
                ]
            )
            // Config-only response: no session. fonts is a literal `[]` (exact
            // match, not EachLike) — the provider returns empty today.
            .willRespondWith(
                status: 200,
                headers: ["Content-Type": Matcher.RegexLike("application/json; charset=utf-8", term: #"application/json(;.*)?"#)],
                body: [
                    "feature_flags": [
                        "rokt-tracking-status": Matcher.SomethingLike(true),
                        "client-timeout-ms": Matcher.SomethingLike(30_000),
                        "ios-sdk-log-font-happy-path": Matcher.SomethingLike(true),
                        "ios-sdk-use-font-register-with-url": Matcher.SomethingLike(false),
                        "mobile-sdk-use-bounding-box": Matcher.SomethingLike(false),
                        "mobile-sdk-use-partner-events": Matcher.SomethingLike(false),
                        "mobile-sdk-use-open-url-from-rokt": Matcher.SomethingLike(false),
                        "mobile-sdk-use-timings-api": Matcher.SomethingLike(false),
                        "mobile-sdk-use-safe-area-removed": Matcher.SomethingLike(false),
                        "mobile-sdk-use-sdk-cache": Matcher.SomethingLike(false),
                        "is-post-purchase-enabled": Matcher.SomethingLike(false),
                        "minimum-post-purchase-schema": Matcher.SomethingLike("2.3.0")
                    ],
                    "fonts": []
                ]
            )

        let expectation = expectation(description: "v2 config request completes")

        // Timeout sized for CI cold-start. See TxnEventsClientPactSpec.
        Self.mockService.run(timeout: 30) { baseURL, done in
            Task {
                defer { done() }
                do {
                    let url = try XCTUnwrap(URL(string: baseURL))
                    let client = TxnInitClient(
                        baseURL: url,
                        accountId: "account-456",
                        sdkVersion: "5.2.2"
                    )
                    let (_, httpResponse) = try await client.initSession(
                        operating_system: "ios",
                        layout_schema_version: "2.1.0"
                    )
                    XCTAssertEqual(httpResponse?.statusCode, 200)
                } catch {
                    XCTFail("TxnInitClient request failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 35)
    }
}
