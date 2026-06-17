import XCTest
import PactSwift
@testable import Rokt_Widget

/// Consumer-driven pact spec for the v2 `/v2/sessions/offers` endpoint.
///
/// Drives `TxnOffersClient.fetchOffers(input:)` — a public method that takes
/// domain inputs (page identifier, customer email, attributes, request-scoped
/// ids) and internally builds the wire request. The pact matchers below
/// describe the EXPECTED wire shape; if `TxnOffersClient` ever drifts from
/// those expectations (e.g., changes the `channel.type` body field or drops the
/// `x-request-id` header), the pact mock service rejects the request and this test fails.
///
/// The test never constructs request headers or body directly, only domain
/// inputs. Wire-shape construction lives entirely in `TxnOffersClient`.
///
/// Matcher policy: the fixed-value string hardcoded in `TxnOffersClient`
/// (`channel.type` = `"msdk"`) is pinned as an exact string rather than
/// `SomethingLike`. `SomethingLike` only matches by type, which would let
/// the client drift to `"ios-mobile"` without failing the consumer test.
/// Per-runtime values (account id, auth token, request id, session ids,
/// page identifier, etc.) stay as `SomethingLike` because they legitimately
/// vary per call.
class TxnOffersClientPactSpec: XCTestCase {
    static var mockService: MockService!

    override class func setUp() {
        super.setUp()
        // PACT_OUTPUT_DIR lets CI redirect the generated JSON to a host path that
        // can be picked up after the simulator exits — without it, PactSwift writes
        // into the simulator data container where GH Actions can't reach it.
        let outputPath = ProcessInfo.processInfo.environment["PACT_OUTPUT_DIR"] ?? "pacts"
        let outputDir = URL(fileURLWithPath: outputPath, isDirectory: true)
        mockService = MockService(
            consumer: "rokt-sdk-ios",
            provider: "transactions-api",
            writePactTo: outputDir
        )
    }

    func test_offersHappyPath_pageDetectionMatches() {
        let validPageTypes = #"^(checkout|confirmation|post_purchase|cart|landing|product)$"#

        Self.mockService
            .uponReceiving("a v2 sessions offers request from rokt-sdk-ios for a configured page")
            .given(ProviderState(description: "a valid offers request is submitted", params: [:]))
            .withRequest(
                method: .POST,
                path: "/v2/sessions/offers",
                headers: [
                    "rokt-account-id": Matcher.SomethingLike("account-456"),
                    "Authorization": Matcher.SomethingLike("Bearer session-token-abc"),
                    "x-request-id": Matcher.SomethingLike("request-id-123"),
                    "rokt-page-instance-guid": Matcher.SomethingLike("page-instance-guid-123"),
                    "Content-Type": "application/json"
                ],
                body: [
                    "session_id": Matcher.SomethingLike("session-123"),
                    "mp_session_id": Matcher.SomethingLike("mp-session-123"),
                    "mpid": Matcher.SomethingLike("mpid-123"),
                    "page": [
                        "page_identifier": Matcher.SomethingLike("checkout-page"),
                        "url": Matcher.SomethingLike("https://merchant.test/checkout")
                    ],
                    "privacy": [
                        "do_not_track": Matcher.SomethingLike(false),
                        "gpc_enabled": Matcher.SomethingLike(false),
                        "do_not_share_or_sell": Matcher.SomethingLike(false)
                    ],
                    "channel": [
                        "type": "msdk",
                        "sdk_version": Matcher.SomethingLike("5.2.2")
                    ],
                    "customer": [
                        "email": Matcher.SomethingLike("user@example.com")
                    ],
                    "attributes": [
                        "standalone": Matcher.SomethingLike("notdefined"),
                        "customer.locale": Matcher.SomethingLike("en-US")
                    ]
                ]
            )
            // Assert only the response fields TxnOffersClient consumes and that
            // the v2 API returns for a configured page: session and token data,
            // the resolved page_instance_guid, and a page_context limited to
            // page_instance_guid, page_id, page_type and is_page_detected. Any
            // other page_context keys and the plugins / placements / event_data
            // / privacy_control blocks are not part of this contract.
            .willRespondWith(
                status: 200,
                headers: ["Content-Type": Matcher.RegexLike("application/json; charset=utf-8", term: #"application/json(;.*)?"#)],
                body: [
                    "session_id": Matcher.SomethingLike("session-123"),
                    "session_token": [
                        "token": Matcher.SomethingLike("rotated-session-token"),
                        "expires_at": Matcher.SomethingLike(1_774_474_053_000)
                    ],
                    "page_context": [
                        "page_instance_guid": Matcher.SomethingLike("page-instance-guid-123"),
                        "page_id": Matcher.SomethingLike("checkout-page"),
                        "page_type": Matcher.RegexLike("checkout", term: validPageTypes),
                        "is_page_detected": Matcher.SomethingLike(true)
                    ],
                    "page_instance_guid": Matcher.SomethingLike("page-instance-guid-123")
                ]
            )

        let expectation = expectation(description: "v2 offers request completes")

        // See TxnEventsClientPactSpec for why this is sized for CI cold-start.
        Self.mockService.run(timeout: 30) { baseURL, done in
            Task {
                defer { done() }
                do {
                    let url = try XCTUnwrap(URL(string: baseURL))
                    let client = TxnOffersClient(
                        baseURL: url,
                        accountId: "account-456",
                        authToken: "Bearer session-token-abc",
                        sessionId: "session-123",
                        mpSessionId: "mp-session-123",
                        mpid: "mpid-123",
                        sdkVersion: "5.2.2",
                        pageInstanceGuid: "page-instance-guid-123"
                    )
                    let input = TxnOffersInput(
                        requestId: "request-id-123",
                        pageIdentifier: "checkout-page",
                        pageURL: "https://merchant.test/checkout",
                        customerEmail: "user@example.com",
                        attributes: [
                            "standalone": "notdefined",
                            "customer.locale": "en-US"
                        ]
                    )
                    let (_, httpResponse) = try await client.fetchOffers(input: input)
                    XCTAssertEqual(httpResponse?.statusCode, 200)
                } catch {
                    XCTFail("TxnOffersClient request failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 35)
    }
}
