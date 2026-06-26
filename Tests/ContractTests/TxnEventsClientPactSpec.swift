import XCTest
import PactSwift
@testable import Rokt_Widget

/// Consumer-driven pact spec for the v2 `/v2/sessions/events` endpoint.
///
/// Drives `TxnEventsClient.recordEvents(events:authToken:)` — the test never constructs
/// request headers or body directly, only domain inputs. Wire-shape
/// construction lives entirely in `TxnEventsClient`, so any drift there
/// (e.g. changing the `channel.type` body field) gets rejected by the pact mock service.
///
/// Mirrors OffersClientPactSpec — see that file's docstring for the
/// matcher policy (exact-match for hardcoded constants, `SomethingLike`
/// for per-runtime values).
class TxnEventsClientPactSpec: XCTestCase {
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
                    "Content-Type": "application/json"
                ],
                body: [
                    "channel": [
                        "type": "msdk",
                        "sdk_version": Matcher.SomethingLike("5.2.2")
                    ],
                    // instance_id must be a canonical 36-character, non-nil UUID;
                    // the API rejects other forms, so the example uses a valid one.
                    "events": Matcher.EachLike([
                        "event_type": Matcher.SomethingLike("impression"),
                        "instance_id": Matcher.SomethingLike("00000000-0000-0000-0000-000000000001"),
                        "timestamp": Matcher.SomethingLike(1_774_474_053_000),
                        "data": [
                            "source_message_id": Matcher.SomethingLike("source-message-001")
                        ]
                    ], min: 1)
                ]
            )
            // Assert only the minimal success shape: session_token and event_ids.
            // errors and warnings are present in the response but not asserted, so
            // the contract stays minimal and tolerant of their contents.
            .willRespondWith(
                status: 202,
                headers: ["Content-Type": Matcher.RegexLike("application/json; charset=utf-8", term: #"application/json(;.*)?"#)],
                body: [
                    "session_token": [
                        "token": Matcher.SomethingLike("next-session-token"),
                        "expires_at": Matcher.SomethingLike(1_774_474_053_000)
                    ],
                    "event_ids": Matcher.EachLike(Matcher.SomethingLike("event-001"), min: 1)
                ]
            )

        let expectation = expectation(description: "v2 events request completes")

        // Timeout sized for CI cold-start: first PactSwift mock-service spin-up +
        // simulator Network.framework init can take 5+ seconds before the request
        // even begins. Once warm, the actual round trip is <100ms.
        Self.mockService.run(timeout: 30) { baseURL, done in
            Task {
                defer { done() }
                do {
                    let url = try XCTUnwrap(URL(string: baseURL))
                    let client = TxnEventsClient(
                        baseURL: url,
                        accountId: "account-456",
                        sdkVersion: "5.2.2"
                    )
                    let event = TxnEvent(
                        eventType: "impression",
                        instanceId: "00000000-0000-0000-0000-000000000001",
                        timestamp: 1_774_474_053_000,
                        data: ["source_message_id": "source-message-001"]
                    )
                    let (_, httpResponse) = try await client.recordEvents(
                        events: [event],
                        authToken: "Bearer session-token-abc"
                    )
                    XCTAssertEqual(httpResponse?.statusCode, 202)
                } catch {
                    XCTFail("TxnEventsClient request failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 35)
    }
}
