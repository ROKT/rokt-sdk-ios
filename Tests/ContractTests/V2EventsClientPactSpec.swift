import XCTest
import PactSwift
@testable import Rokt_Widget

/// Consumer-driven pact spec for the v2 `/v2/sessions/events` endpoint.
///
/// Drives `V2EventsClient.recordEvents(events:)` — the test never constructs
/// request headers or body directly, only domain inputs. Wire-shape
/// construction lives entirely in `V2EventsClient`, so any drift there
/// (e.g. switching `rokt-integration-type` from `"msdk-ios"` to
/// `"ios-mobile"`) gets rejected by the pact mock service.
///
/// Mirrors V2OffersClientPactSpec — see that file's docstring for the
/// matcher policy (exact-match for hardcoded constants, `SomethingLike`
/// for per-runtime values).
class V2EventsClientPactSpec: XCTestCase {
    static var mockService: MockService!

    override class func setUp() {
        super.setUp()
        // PACT_OUTPUT_DIR lets CI redirect the generated JSON to a host path
        // reachable after the simulator exits — without it, PactSwift writes
        // into the simulator data container where GH Actions can't reach it.
        let outputPath = ProcessInfo.processInfo.environment["PACT_OUTPUT_DIR"] ?? "pacts"
        let outputDir = URL(fileURLWithPath: outputPath, isDirectory: true)
        mockService = MockService(
            consumer: "rokt-sdk-ios",
            provider: "transactions-api",
            writePactTo: outputDir
        )
    }

    func test_recordEventsHappyPath_acceptsSingleImpression() {
        Self.mockService
            .uponReceiving("a v2 sessions events request from rokt-sdk-ios with one impression event")
            .given(ProviderState(description: "a valid session token is provided", params: [:]))
            .withRequest(
                method: .POST,
                path: "/v2/sessions/events",
                headers: [
                    "rokt-account-id": Matcher.SomethingLike("account-456"),
                    "Authorization": Matcher.SomethingLike("Bearer session-token-abc"),
                    "rokt-platform-type": "iOS",
                    "rokt-integration-type": "msdk-ios",
                    "Content-Type": "application/json"
                ],
                body: [
                    "channel": [
                        "type": "msdk",
                        "sdk_version": Matcher.SomethingLike("5.2.2")
                    ],
                    "events": Matcher.EachLike([
                        "event_type": Matcher.SomethingLike("impression"),
                        "instance_id": Matcher.SomethingLike("instance-001"),
                        "timestamp": Matcher.SomethingLike(1_774_474_053_000),
                        "data": [
                            "source_message_id": Matcher.SomethingLike("source-message-001")
                        ]
                    ], min: 1)
                ]
            )
            .willRespondWith(
                status: 202,
                headers: ["Content-Type": "application/json"],
                body: [
                    "session_token": [
                        "token": Matcher.SomethingLike("next-session-token"),
                        "expires_at": Matcher.SomethingLike(1_774_474_053_000)
                    ],
                    "event_ids": Matcher.EachLike(Matcher.SomethingLike("event-001"), min: 1),
                    "errors": [],
                    "warnings": []
                ]
            )

        let expectation = expectation(description: "v2 events request completes")

        Self.mockService.run(timeout: 5) { baseURL, done in
            Task {
                defer { done() }
                do {
                    let url = try XCTUnwrap(URL(string: baseURL))
                    let client = V2EventsClient(
                        baseURL: url,
                        accountId: "account-456",
                        authToken: "Bearer session-token-abc",
                        sdkVersion: "5.2.2"
                    )
                    let event = V2Event(
                        eventType: "impression",
                        instanceId: "instance-001",
                        timestamp: 1_774_474_053_000,
                        data: ["source_message_id": "source-message-001"]
                    )
                    let (_, response) = try await client.recordEvents(events: [event])
                    let httpResponse = response as? HTTPURLResponse
                    XCTAssertEqual(httpResponse?.statusCode, 202)
                } catch {
                    XCTFail("V2EventsClient request failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 6)
    }
}
