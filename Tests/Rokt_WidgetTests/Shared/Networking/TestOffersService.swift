import XCTest
@testable import Rokt_Widget

/// Covers the offers service with a stubbed transport: a successful response is
/// decoded, rolls the session token forward, and is adapted into the experience
/// string the renderer consumes; retryable statuses are retried; an unexpected
/// status or missing body surfaces as a failure; and the request carries the
/// derived privacy control and sanitised attributes.
final class TestOffersService: XCTestCase {

    /// One stubbed transport outcome: body + status, or a transport-level error.
    private struct StubResponse {
        let data: Data?
        let status: Int
        let error: Error?
        init(data: Data?, status: Int, error: Error? = nil) {
            self.data = data
            self.status = status
            self.error = error
        }
    }

    private final class StubHTTPClient: HTTPClientAdapter {
        private let responses: [StubResponse]
        private(set) var requestCount = 0
        private(set) var lastParameters: RoktHTTPParameters?
        private(set) var lastHeaders: RoktHTTPHeaders?

        init(responseData: Data?, statusCode: Int) {
            responses = [StubResponse(data: responseData, status: statusCode)]
        }

        init(responses: [(data: Data?, status: Int)]) {
            self.responses = responses.map { StubResponse(data: $0.data, status: $0.status) }
        }

        init(sequence: [StubResponse]) {
            responses = sequence
        }

        func updateTimeout(timeout: Double) {}

        @discardableResult
        func startRequestWith(
            urlAddress: String,
            method: RoktHTTPMethod,
            parameters: RoktHTTPParameters?,
            parameterArray: RoktHTTPParameterArray?,
            headers: RoktHTTPHeaders?,
            onRequestStart: (() -> Void)?,
            requestTimeout: TimeInterval?,
            completionQueue: DispatchQueue,
            completionHandler: ((RoktHTTPRequestResult) -> Void)?
        ) -> URLRequest? {
            lastParameters = parameters
            lastHeaders = headers
            let response = responses[min(requestCount, responses.count - 1)]
            requestCount += 1
            let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
            let result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: response.status, httpVersion: nil, headerFields: nil),
                responseData: response.data,
                responseError: response.error,
                jsonSerialisedResponseData: .success(NSNull())
            )
            completionQueue.async { completionHandler?(result) }
            return nil
        }

        func downloadFile(
            source urlAddress: String,
            destinationURL: URL,
            options: [RoktDownloadOptions],
            parameters: RoktHTTPParameters?,
            headers: RoktHTTPHeaders?,
            requestTimeout: TimeInterval?,
            completionQueue: DispatchQueue,
            completionHandler: ((RoktDownloadResult) -> Void)?
        ) {}
    }

    private let offersResponse = """
    {
      "session_id": "session-1",
      "session_token": { "token": "rolled-token", "expires_at": 32503680000000 },
      "page_instance_guid": "pig-1",
      "page_context": { "page_id": "checkout", "token": "page-token" },
      "plugins": [
        { "plugin": { "id": "plugin-1", "config": {
          "token": "plugin-token",
          "outer_layout_schema": "{\\"layout\\":{\\"node\\":\\"outer\\"}}",
          "slots": []
        } } }
      ]
    }
    """

    private func makeService(
        _ stub: StubHTTPClient,
        sessionManager: TxnSessionManager = TxnSessionManager(),
        deviceHeaders: [String: String] = [:],
        triggeredEvents: @escaping () -> [TriggeredRealTimeEvent] = { [] },
        captureEvents: @escaping ([UntriggeredRealTimeEvent]) -> Void = { _ in },
        maxRetries: Int = 0
    ) -> OffersService {
        // Event store seams default to inert so tests never touch the global singleton.
        OffersService(
            environment: .Prod,
            accountId: "account-1",
            sdkVersion: "1.0.0",
            layoutSchemaVersion: "2.8",
            sessionManager: sessionManager,
            httpClient: stub,
            deviceHeaders: deviceHeaders,
            maxRetries: maxRetries,
            sleep: { _ in },
            triggeredEvents: triggeredEvents,
            captureEvents: captureEvents
        )
    }

    func test_getExperienceData_adaptsResponseAndRollsTokenForward() async {
        let sessionManager = TxnSessionManager()
        let service = makeService(StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200),
                                  sessionManager: sessionManager)

        let completed = expectation(description: "offers experience returned")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            let page = page ?? ""
            XCTAssertTrue(page.contains("\"placementContext\""))
            XCTAssertTrue(page.contains("\"rolled-token\""))
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        await fulfillment(of: [completed], timeout: 5)
        // The session id and refreshed token are rolled forward for the next call.
        let header = await sessionManager.authorizationHeader
        let sessionId = await sessionManager.currentSessionId
        XCTAssertEqual(header, "Bearer rolled-token")
        XCTAssertEqual(sessionId, "session-1")
    }

    func test_getExperienceData_retriesRetryableStatusThenSucceeds() {
        let stub = StubHTTPClient(responses: [(nil, 503), (Data(offersResponse.utf8), 200)])
        let service = makeService(stub, maxRetries: 1)

        let completed = expectation(description: "offers retried then succeeded")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            XCTAssertNotNil(page)
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_getExperienceData_reportsFailureWithStatusCode() {
        let service = makeService(StubHTTPClient(responseData: nil, statusCode: 500))

        let failed = expectation(description: "offers failed")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, statusCode, _ in
            XCTAssertEqual(statusCode, 500)
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
    }

    func test_getExperienceData_failsWhenResponseBodyMissing() {
        let service = makeService(StubHTTPClient(responseData: nil, statusCode: 200))

        let failed = expectation(description: "missing body fails")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, _, _ in
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
    }

    func test_getExperienceData_buildsPrivacyControlAndSanitisesAttributesAndFiresOnRequestStart() {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let service = makeService(stub)

        var onRequestStartFired = false
        let completed = expectation(description: "request built")
        service.getExperienceData(
            viewName: "checkout",
            attributes: ["noFunctional": "true", "doNotShareOrSell": "false", "gpcEnabled": "true", "email": "a@b.com"],
            config: nil,
            onRequestStart: { onRequestStartFired = true },
            successLayout: { _ in completed.fulfill() },
            failure: { error, _, _ in XCTFail("unexpected failure: \(error)") }
        )

        wait(for: [completed], timeout: 5)
        XCTAssertTrue(onRequestStartFired)

        let body = try? XCTUnwrap(stub.lastParameters as? [String: Any])
        let privacyControl = body?["privacy_control"] as? [String: Any]
        XCTAssertEqual(privacyControl?["no_functional"] as? Bool, true)
        XCTAssertEqual(privacyControl?["do_not_share_or_sell"] as? Bool, false)

        // gpc_enabled travels under a separate top-level `privacy` object, not privacy_control.
        let privacy = body?["privacy"] as? [String: Any]
        XCTAssertEqual(privacy?["gpc_enabled"] as? Bool, true)
        XCTAssertNil(privacyControl?["gpc_enabled"])

        let attributes = body?["attributes"] as? [String: Any]
        XCTAssertEqual(attributes?["email"] as? String, "a@b.com")
        // Privacy keys (incl. gpcEnabled) are stripped from the forwarded attributes.
        XCTAssertNil(attributes?["noFunctional"])
        XCTAssertNil(attributes?["gpcEnabled"])
    }

    func test_getExperienceData_forwardsDeviceHeaders() {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let service = makeService(stub, deviceHeaders: [
            "rokt-os-type": "iOS",
            "rokt-package-name": "com.rokt.test"
        ])

        let completed = expectation(description: "offers experience returned")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        // Device headers (incl. the load-bearing rokt-package-name) reach the request.
        XCTAssertEqual(stub.lastHeaders?["rokt-os-type"], "iOS")
        XCTAssertEqual(stub.lastHeaders?["rokt-package-name"], "com.rokt.test")
        // rokt-txn-shadow is no longer sent; mobile shadow routing is session-id-shape driven.
        XCTAssertNil(stub.lastHeaders?["rokt-txn-shadow"])
    }

    func test_getExperienceData_omitsAuthorizationUntilTokenRolledForward() {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let service = makeService(stub, sessionManager: TxnSessionManager())

        // First call: no live token, so Authorization is omitted entirely — the server
        // then mints a fresh session rather than seeing a blank `Bearer` header.
        let first = expectation(description: "first offers call")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            first.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })
        wait(for: [first], timeout: 5)
        XCTAssertNil(stub.lastHeaders?["Authorization"])

        // The response rolled a non-expired token forward, so the next call carries it.
        let second = expectation(description: "second offers call")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            second.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })
        wait(for: [second], timeout: 5)
        XCTAssertEqual(stub.lastHeaders?["Authorization"], "Bearer rolled-token")
    }

    func test_getExperienceData_forwardsTriggeredEventsOnlyWhenSessionLive() throws {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let eventTime = EventDateFormatter.dateFormatter.string(from: Date(timeIntervalSince1970: 1_782_484_201))
        let service = makeService(stub, sessionManager: TxnSessionManager(), triggeredEvents: {
            [TriggeredRealTimeEvent(parentGuid: "p", eventType: "impression", eventTime: eventTime, payload: "pl")]
        })

        // No live token yet: events are not forwarded (nothing to attribute them to). This
        // call rolls a non-expired token forward via the response.
        let first = expectation(description: "first call")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            first.fulfill()
        }, failure: { error, _, _ in XCTFail("unexpected failure: \(error)") })
        wait(for: [first], timeout: 5)
        XCTAssertNil((stub.lastParameters as? [String: Any])?["events"])

        // With a live token the triggered events ride on the request as events[] in the
        // /v2/sessions/events shape (event_type + epoch-ms timestamp + data.payload, no instance_id).
        let second = expectation(description: "second call")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            second.fulfill()
        }, failure: { error, _, _ in XCTFail("unexpected failure: \(error)") })
        wait(for: [second], timeout: 5)

        let body = stub.lastParameters as? [String: Any]
        let events = try XCTUnwrap(body?["events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["event_type"] as? String, "impression")
        XCTAssertEqual(events.first?["timestamp"] as? Int, 1_782_484_201_000)
        XCTAssertEqual((events.first?["data"] as? [String: Any])?["payload"] as? String, "pl")
        XCTAssertNil(events.first?["instance_id"])
    }

    func test_getExperienceData_capturesResponseEventDataForNextCall() {
        let responseWithEvents = """
        {
          "session_id": "session-1",
          "session_token": { "token": "rolled-token", "expires_at": 32503680000000 },
          "page_context": { "page_id": "checkout" },
          "plugins": [
            { "plugin": { "id": "plugin-1", "config": {
              "token": "plugin-token",
              "outer_layout_schema": "{\\"layout\\":{\\"node\\":\\"outer\\"}}",
              "slots": []
            } } }
          ],
          "event_data": {
            "parent-1": { "token": "tok", "events": { "SignalResponse": { "event_type": "x", "payload": "y" } } }
          }
        }
        """
        let stub = StubHTTPClient(responseData: Data(responseWithEvents.utf8), statusCode: 200)
        var captured: [UntriggeredRealTimeEvent] = []
        let service = makeService(stub, captureEvents: { captured = $0 })

        let completed = expectation(description: "offers response captured")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })
        wait(for: [completed], timeout: 5)

        // The echoed event_data is flattened into untriggered events for the next placement.
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.triggerGuid, "parent-1")
        XCTAssertEqual(captured.first?.triggerEvent, "SignalResponse")
        XCTAssertEqual(captured.first?.eventType, "x")
        XCTAssertEqual(captured.first?.payload, "y")
    }

    func test_getExperienceData_retriesTransientTransportErrorThenSucceeds() {
        let timeout = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let stub = StubHTTPClient(sequence: [
            StubResponse(data: nil, status: 0, error: timeout),
            StubResponse(data: Data(offersResponse.utf8), status: 200)
        ])
        let service = makeService(stub, maxRetries: 1)

        let completed = expectation(description: "transient transport error retried then succeeded")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            XCTAssertNotNil(page)
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_getExperienceData_doesNotRetryNonTransportError() {
        let nonTransport = NSError(domain: "Custom", code: 1)
        let stub = StubHTTPClient(sequence: [StubResponse(data: nil, status: 0, error: nonTransport)])
        let service = makeService(stub, maxRetries: 2)

        let failed = expectation(description: "non-transport error fails without retry")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, _, _ in
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 1)
    }

    func test_getExperienceData_doesNotRetryNonRetryableURLError() {
        // A URL-domain error whose code is outside the transient set must fail fast.
        let badResponse = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
        let stub = StubHTTPClient(sequence: [StubResponse(data: nil, status: 0, error: badResponse)])
        let service = makeService(stub, maxRetries: 2)

        let failed = expectation(description: "non-retryable URL error fails without retry")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, _, _ in
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 1)
    }

    func test_getExperienceData_usesDefaultBackoffSleepWhenNotInjected() {
        // Build the service without injecting `sleep` so the real backoff closure runs
        // during the retry; a tiny backoff keeps the delay negligible.
        let stub = StubHTTPClient(responses: [(nil, 503), (Data(offersResponse.utf8), 200)])
        let service = OffersService(
            environment: .Prod,
            accountId: "account-1",
            sdkVersion: "1.0.0",
            layoutSchemaVersion: "2.8",
            sessionManager: TxnSessionManager(),
            httpClient: stub,
            maxRetries: 1,
            baseBackoff: 0.001,
            triggeredEvents: { [] }
        )

        let completed = expectation(description: "default backoff sleep used on retry")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            XCTAssertNotNil(page)
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_getExperienceData_onUnauthorized_dropsSessionAndReMintsWithoutToken() {
        // First 200 rolls a live token forward; the second call's first request carries it,
        // gets 401, so the session is dropped and offers is re-minted once with no
        // Authorization — the gateway then issues a fresh session (200). Self-heals.
        let stub = StubHTTPClient(responses: [
            (Data(offersResponse.utf8), 200), // call 1: roll a live token forward
            (nil, 401), // call 2: token rejected
            (Data(offersResponse.utf8), 200) // call 2 re-mint: fresh session
        ])
        let service = makeService(stub, sessionManager: TxnSessionManager())

        let first = expectation(description: "first call rolls token")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            first.fulfill()
        }, failure: { error, _, _ in XCTFail("unexpected failure: \(error)") })
        wait(for: [first], timeout: 5)

        let second = expectation(description: "401 self-heals via re-mint")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            second.fulfill()
        }, failure: { error, _, _ in XCTFail("unexpected failure: \(error)") })
        wait(for: [second], timeout: 5)

        // Three transport calls total: roll, 401, re-mint.
        XCTAssertEqual(stub.requestCount, 3)
        // The re-mint carried no Authorization because the session was cleared on the 401.
        XCTAssertNil(stub.lastHeaders?["Authorization"])
    }

    func test_getExperienceData_onRepeatedUnauthorized_failsAfterSingleReMint() {
        // A 401 that persists after the re-mint must fail (not loop): one original request
        // plus one re-mint, then surface the 401.
        let stub = StubHTTPClient(responses: [(nil, 401), (nil, 401)])
        let service = makeService(stub)

        let failed = expectation(description: "repeated 401 fails after one re-mint")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, statusCode, _ in
            XCTAssertEqual(statusCode, 401)
            failed.fulfill()
        })
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
    }
}
