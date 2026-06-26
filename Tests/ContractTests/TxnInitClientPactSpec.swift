import XCTest
import PactSwift
@testable import Rokt_Widget

/// Consumer-driven pact spec for `POST /v2/sessions/init`. Drives
/// `TxnInitClient.initSession` through the pact mock service so any drift
/// in the client's wire shape fails here.
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

    func test_sessionInitHappyPath_returnsSessionAndFeatureFlags() {
        Self.mockService
            .uponReceiving("a v2 sessions init request from rokt-sdk-ios initializes a session and returns feature flags")
            .given(ProviderState(description: "a valid session initialization request is submitted", params: [:]))
            .withRequest(
                method: .POST,
                path: "/v2/sessions/init",
                // Cold init: no Authorization — the client has no session token yet,
                // so the server mints one. x-request-id is always sent.
                headers: [
                    "rokt-account-id": Matcher.RegexLike("account-456", term: #".+"#),
                    "x-request-id": Matcher.RegexLike("request-id-123", term: #".+"#),
                    "Content-Type": "application/json"
                ],
                body: [
                    "operating_system": "ios",
                    "sdk_version": Matcher.SomethingLike("5.2.2"),
                    "layout_schema_version": Matcher.SomethingLike("2.1.0")
                ]
            )
            // fonts is a literal `[]` (exact match), not EachLike: the provider always
            // returns empty today, and EachLike's default min:1 would demand a non-empty array.
            .willRespondWith(
                status: 200,
                headers: ["Content-Type": Matcher.RegexLike("application/json; charset=utf-8", term: #"application/json(;.*)?"#)],
                body: [
                    "session_id": Matcher.SomethingLike("550e8400-e29b-41d4-a716-446655440000"),
                    "session_token": [
                        "token": Matcher.SomethingLike("pact-stub-session-token"),
                        "expires_at": Matcher.SomethingLike(1_774_474_053_000)
                    ],
                    "feature_flags": [
                        // Provider returns these four verbatim — pin exact (not type) match.
                        "rokt-tracking-status": true,
                        "client-timeout-ms": 30_000,
                        "ios-sdk-log-font-happy-path": true,
                        "ios-sdk-use-font-register-with-url": false,
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

        let expectation = expectation(description: "v2 sessions init request completes")

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
