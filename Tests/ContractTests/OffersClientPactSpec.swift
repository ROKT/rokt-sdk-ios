import XCTest
import PactSwift
@testable import Rokt_Widget

/// Consumer-driven pact spec for the `/v2/sessions/offers` endpoint.
///
/// Drives `OffersClient.fetchOffers(input:)` — a public method that takes
/// domain inputs (page identifier, customer email, attributes, request-scoped
/// ids) and internally builds the wire request. The pact matchers below
/// describe the EXPECTED wire shape; if `OffersClient` ever drifts from
/// those expectations (e.g., changes the `channel.type` body field or drops the
/// `x-request-id` header), the pact mock service rejects the request and this test fails.
///
/// The test never constructs request headers or body directly, only domain
/// inputs. Wire-shape construction lives entirely in `OffersClient`.
///
/// Session identity is carried solely by the `Authorization: Bearer <jwt>`
/// header (the provider reads it from the JWT `sub` claim) — there is
/// intentionally no `session_id`/`mp_session_id`/`mpid` in the request body.
/// Privacy consent travels under `privacy_control`; `customer` and `page.url`
/// are omitted to mirror the Android offers contract.
///
/// Matcher policy: the fixed-value string hardcoded in `OffersClient`
/// (`channel.type` = `"msdk"`) is pinned as an exact string rather than
/// `SomethingLike`. `SomethingLike` only matches by type, which would let
/// the client drift to `"ios-mobile"` without failing the consumer test.
/// Per-runtime values (account id, auth token, request id, page identifier,
/// etc.) stay as `SomethingLike` because they legitimately vary per call.
class OffersClientPactSpec: XCTestCase {
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
                    "rokt-package-name": Matcher.SomethingLike("com.rokt.example"),
                    "Content-Type": "application/json"
                ],
                body: [
                    "page": [
                        "page_identifier": Matcher.SomethingLike("checkout-page")
                    ],
                    "privacy_control": [
                        "no_functional": Matcher.SomethingLike(false),
                        "no_targeting": Matcher.SomethingLike(false),
                        "do_not_share_or_sell": Matcher.SomethingLike(false)
                    ],
                    "channel": [
                        "type": "msdk",
                        "sdk_version": Matcher.SomethingLike("5.2.2"),
                        "rokt_platform_type": "iOS"
                    ],
                    "attributes": [
                        "standalone": Matcher.SomethingLike("notdefined"),
                        "customer.locale": Matcher.SomethingLike("en-US")
                    ]
                ]
            )
            // Assert only the response fields OffersClient consumes and that
            // the v2 API returns for a configured page: session and token data,
            // the resolved page_instance_guid, and a page_context limited to
            // page_instance_guid, page_id, page_type and is_page_detected. Any
            // other page_context keys and the plugins / placements / event_data
            // / privacy_control blocks are not part of this contract.
            //
            // is_page_detected is pinned to an exact `true` (not SomethingLike):
            // it is the signal that page detection succeeded, and detection only
            // succeeds because this request carries rokt-package-name. A
            // type-only match would let the provider return false — i.e. the
            // missing-package-name regression — and still pass.
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
                        "is_page_detected": true
                    ],
                    "page_instance_guid": Matcher.SomethingLike("page-instance-guid-123")
                ]
            )

        let expectation = expectation(description: "v2 offers request completes")

        // See V2EventsClientPactSpec for why this is sized for CI cold-start.
        Self.mockService.run(timeout: 30) { baseURL, done in
            Task {
                defer { done() }
                do {
                    let url = try XCTUnwrap(URL(string: baseURL))
                    let client = OffersClient(
                        baseURL: url,
                        accountId: "account-456",
                        authToken: "Bearer session-token-abc",
                        sdkVersion: "5.2.2",
                        pageInstanceGuid: "page-instance-guid-123"
                    )
                    let input = OffersInput(
                        requestId: "request-id-123",
                        pageIdentifier: "checkout-page",
                        attributes: [
                            "standalone": "notdefined",
                            "customer.locale": "en-US"
                        ],
                        privacyControl: SelectPrivacyControl(
                            noFunctional: false,
                            noTargeting: false,
                            doNotShareOrSell: false
                        )
                    )
                    let (_, httpResponse) = try await client.fetchOffers(input: input)
                    XCTAssertEqual(httpResponse?.statusCode, 200)
                } catch {
                    XCTFail("OffersClient request failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 35)
    }
}
