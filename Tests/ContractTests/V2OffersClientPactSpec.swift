import XCTest
import PactSwift

final class V2OffersClientPactSpec: XCTestCase {
    static var mockService: MockService!

    override class func setUp() {
        super.setUp()
        let outputDir = URL(fileURLWithPath: "pacts", isDirectory: true)
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
                    "rokt-platform-type": Matcher.SomethingLike("iOS"),
                    "rokt-integration-type": Matcher.SomethingLike("msdk-ios"),
                    "x-request-id": Matcher.SomethingLike("request-id-123"),
                    "rokt-page-instance-guid": Matcher.SomethingLike("page-instance-guid-123"),
                    "Content-Type": "application/json",
                ],
                body: [
                    "session_id": Matcher.SomethingLike("session-123"),
                    "mp_session_id": Matcher.SomethingLike("mp-session-123"),
                    "mpid": Matcher.SomethingLike("mpid-123"),
                    "page": [
                        "page_identifier": Matcher.SomethingLike("checkout-page"),
                        "url": Matcher.SomethingLike("https://merchant.test/checkout"),
                    ],
                    "privacy": [
                        "do_not_track": Matcher.SomethingLike(false),
                        "gpc_enabled": Matcher.SomethingLike(false),
                        "do_not_share_or_sell": Matcher.SomethingLike(false),
                    ],
                    "channel": [
                        "type": Matcher.SomethingLike("msdk"),
                        "sdk_version": Matcher.SomethingLike("5.2.2"),
                    ],
                    "customer": [
                        "email": Matcher.SomethingLike("user@example.com"),
                    ],
                    "attributes": [
                        "standalone": Matcher.SomethingLike("notdefined"),
                        "customer.locale": Matcher.SomethingLike("en-US"),
                    ],
                ]
            )
            .willRespondWith(
                status: 200,
                headers: ["Content-Type": "application/json"],
                body: [
                    "session_id": Matcher.SomethingLike("session-123"),
                    "session_token": [
                        "token": Matcher.SomethingLike("rotated-session-token"),
                        "expires_at": Matcher.SomethingLike(1_774_474_053_000),
                    ],
                    "page_context": [
                        "rokt_tag_id": Matcher.SomethingLike("tag-123"),
                        "page_instance_guid": Matcher.SomethingLike("page-instance-guid-123"),
                        "page_id": Matcher.SomethingLike("checkout-page"),
                        "page_type": Matcher.RegexLike("checkout", term: validPageTypes),
                        "language": Matcher.SomethingLike("en-US"),
                        "is_page_detected": Matcher.SomethingLike(true),
                        "page_variant_name": Matcher.SomethingLike("control"),
                    ],
                    "plugins": [],
                    "placements": [],
                    "event_data": [:],
                    "page_instance_guid": Matcher.SomethingLike("page-instance-guid-123"),
                    "privacy_control": [
                        "limited_use": Matcher.SomethingLike(false),
                    ],
                ]
            )

        let expectation = expectation(description: "v2 offers request completes")

        Self.mockService.run(timeout: 5) { baseURL, done in
            Task {
                defer { done() }
                do {
                    let url = try XCTUnwrap(URL(string: baseURL))
                    let client = V2OffersClient(baseURL: url)
                    let headers = V2OffersClient.Headers.iOSDefaults(
                        accountId: "account-456",
                        authorization: "Bearer session-token-abc",
                        requestId: "request-id-123",
                        pageInstanceGuid: "page-instance-guid-123"
                    )
                    let body = V2OffersClient.Request(
                        sessionId: "session-123",
                        mpSessionId: "mp-session-123",
                        mpid: "mpid-123",
                        page: .init(
                            pageIdentifier: "checkout-page",
                            url: "https://merchant.test/checkout"
                        ),
                        privacy: .init(
                            doNotTrack: false,
                            gpcEnabled: false,
                            doNotShareOrSell: false
                        ),
                        channel: .init(type: "msdk", sdkVersion: "5.2.2"),
                        customer: .init(email: "user@example.com"),
                        attributes: [
                            "standalone": "notdefined",
                            "customer.locale": "en-US",
                        ]
                    )
                    let (_, response) = try await client.sendOffers(headers: headers, body: body)
                    let httpResponse = response as? HTTPURLResponse
                    XCTAssertEqual(httpResponse?.statusCode, 200)
                } catch {
                    XCTFail("V2OffersClient request failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 6)
    }
}
