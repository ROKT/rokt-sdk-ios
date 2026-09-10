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

    /// Stands in for the JSON body encoder inside a real `RoktHTTPClient`: it reports when the body is encoded, then
    /// forwards to the real encoder, so the bytes are the production bytes.
    private final class RecordingBodyEncoder: RoktHTTPParameterEncoder {
        // The client picks its body encoder by this id.
        let id = String(describing: RoktHTTPBodyEncoder.self)
        private let wrapped = RoktHTTPBodyEncoder()
        /// Runs on the building thread as the body is encoded.
        var onEncode: (() -> Void)?

        func encode(
            parameterEncodable: RoktHTTPParameterEncodable,
            parameters: RoktHTTPParameters?,
            parameterArray: RoktHTTPParameterArray?,
            httpMethod: RoktHTTPMethod
        ) -> RoktHTTPParameterEncodable {
            onEncode?()
            return wrapped.encode(
                parameterEncodable: parameterEncodable,
                parameters: parameters,
                parameterArray: parameterArray,
                httpMethod: httpMethod
            )
        }
    }

    /// What the transport saw of one request, read as the request was handed to it. The body stream is read there,
    /// once, because the session owns it afterwards; header names are lowercased, since HTTP compares them that way.
    private struct SentRequest {
        let url: URL?
        let method: String?
        let headers: [String: String]?
        let body: NSDictionary?

        init(_ request: URLRequest) {
            url = request.url
            method = request.httpMethod
            // URLSession adds Content-Length to a body-bearing request before the transport sees it; the SDK never sets it.
            headers = request.allHTTPHeaderFields.map { fields in
                Dictionary(uniqueKeysWithValues: fields.map { ($0.key.lowercased(), $0.value) })
                    .filter { $0.key != "content-length" }
            }
            body = request.bodyStreamAsJSON() as? NSDictionary
        }
    }

    override func tearDown() {
        // The URL protocol stub's observer and canned response are static: a test that installed them leaves none
        // behind for the next.
        RoktHTTPUrlProtocolStub.stopInterceptingRequests()
        super.tearDown()
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
        maxRetries: Int = 0,
        sleep: @escaping (TimeInterval) async throws -> Void = { _ in }
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
            sleep: sleep,
            triggeredEvents: triggeredEvents,
            captureEvents: captureEvents
        )
    }

    func test_getExperienceData_passesResponseThroughAndRollsTokenForward() async {
        let sessionManager = TxnSessionManager()
        let service = makeService(StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200),
                                  sessionManager: sessionManager)

        let completed = expectation(description: "offers experience returned")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            let page = page ?? ""
            // The raw snake_case selection response is forwarded to the renderer unchanged.
            XCTAssertTrue(page.contains("\"page_context\""))
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

    func test_getExperienceData_farFutureExpiry_isAdoptedAndBounded() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let store = InMemoryTxnSessionStore()
        let sessionManager = TxnSessionManager(roktTagId: "tag-1", store: store, clock: { now })
        let service = makeService(StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200),
                                  sessionManager: sessionManager)

        let completed = expectation(description: "offers experience returned")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        await fulfillment(of: [completed], timeout: 5)
        // The fixture's far-future expiry is adopted, then persisted as an integer no later than now + maxTokenTTL.
        let header = await sessionManager.authorizationHeader
        XCTAssertEqual(header, "Bearer rolled-token")
        let persisted = try XCTUnwrap(store.string(forKey: TxnSessionStoreKeys.expiresAt).flatMap { Int64($0) })
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let capMs = Int64(now.addingTimeInterval(TxnSessionPersistence.maxTokenTTL).timeIntervalSince1970 * 1000)
        XCTAssertGreaterThan(persisted, nowMs)
        XCTAssertLessThanOrEqual(persisted, capMs)
    }

    func test_productCarouselResponsePreservesRawDataSessionAndEvents() async throws {
        let data = try ProductCarouselFixture.data()
        let sessionManager = TxnSessionManager()
        let stub = StubHTTPClient(responseData: data, statusCode: 200)
        var capturedEvents: [UntriggeredRealTimeEvent] = []
        let service = makeService(stub, sessionManager: sessionManager, captureEvents: { capturedEvents = $0 })
        let completed = expectation(description: "Product selection forwarded")

        service.getExperienceData(viewName: "example-checkout", attributes: [:], config: nil, successLayout: { raw in
            XCTAssertEqual(raw.map { Data($0.utf8) }, data)
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("Unexpected selection failure: \(error)")
            completed.fulfill()
        })
        await fulfillment(of: [completed], timeout: 5)

        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertNil(stub.lastHeaders?["Authorization"])
        let sessionId = await sessionManager.currentSessionId
        let authorization = await sessionManager.authorizationHeader
        XCTAssertEqual(sessionId, "synthetic-product-carousel-session")
        XCTAssertEqual(authorization, "Bearer synthetic-session-token-not-a-jwt")
        XCTAssertEqual(capturedEvents.count, 17)
        let productEvents = capturedEvents.filter { $0.triggerEvent == "SignalProductItemResponse" }
        let expectedGuids = Set(["a", "b", "c", "d"].flatMap { letter in
            ["positive", "details"].map { "response:example/product-\(letter)/\($0)" }
        })
        XCTAssertEqual(Set(productEvents.compactMap(\.triggerGuid)), expectedGuids)
        for event in productEvents {
            XCTAssertEqual(event.eventType, "SignalProductItemResponse")
            XCTAssertEqual(event.payload, event.triggerGuid.map { "synthetic-payload:\($0)" })
        }
        XCTAssertTrue(capturedEvents.contains { $0.triggerGuid == "response:example/before/accept" })
        XCTAssertTrue(capturedEvents.contains { $0.triggerGuid == "response:example/after/decline" })

        let subsequent = expectation(description: "Subsequent request uses refreshed session")
        service.getExperienceData(viewName: "example-checkout", attributes: [:], config: nil, successLayout: { raw in
            XCTAssertEqual(raw.map { Data($0.utf8) }, data)
            subsequent.fulfill()
        }, failure: { error, _, _ in
            XCTFail("Unexpected subsequent selection failure: \(error)")
            subsequent.fulfill()
        })
        await fulfillment(of: [subsequent], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
        XCTAssertEqual(stub.lastHeaders?["Authorization"], "Bearer synthetic-session-token-not-a-jwt")
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
            "rokt-package-name": "com.rokt.test",
            "rokt-package-version": "1.2.3"
        ])

        let completed = expectation(description: "offers experience returned")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        // Device headers (incl. partner app identity) reach the request.
        XCTAssertEqual(stub.lastHeaders?["rokt-os-type"], "iOS")
        XCTAssertEqual(stub.lastHeaders?["rokt-package-name"], "com.rokt.test")
        XCTAssertEqual(stub.lastHeaders?["rokt-package-version"], "1.2.3")
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

    /// A retry re-sends the attributes and token captured for the first attempt. When the session is reset while
    /// the backoff after a retryable server error runs, the retry is not sent and the placement is discarded.
    func test_getExperienceData_sessionResetDuringRetryBackoffAfterServerError_sendsNoRetry() {
        let stub = StubHTTPClient(responseData: nil, statusCode: 503)
        var sessionReset = false
        let service = makeService(stub, maxRetries: 1, sleep: { _ in sessionReset = true })

        let discarded = expectation(description: "the retry is not sent once the session was reset")
        service.getExperienceData(
            viewName: "checkout",
            attributes: [:],
            config: nil,
            sendGate: { start in
                guard !sessionReset else { return false }
                start()
                return true
            },
            successLayout: { _ in XCTFail("unexpected success") },
            failure: { error, statusCode, _ in
                XCTAssertEqual(error as? OffersService.OffersError, .discardedBeforeSend)
                XCTAssertNil(statusCode, "a discard carries no status code")
                discarded.fulfill()
            }
        )

        wait(for: [discarded], timeout: 5)
        XCTAssertEqual(stub.requestCount, 1, "the departing customer's attributes and token are not sent again")
    }

    /// The same window after a transient transport failure: the reset during the backoff stops the retry.
    func test_getExperienceData_sessionResetDuringRetryBackoffAfterTransportError_sendsNoRetry() {
        let timeout = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let stub = StubHTTPClient(sequence: [StubResponse(data: nil, status: 0, error: timeout)])
        var sessionReset = false
        let service = makeService(stub, maxRetries: 1, sleep: { _ in sessionReset = true })

        let discarded = expectation(description: "the retry is not sent once the session was reset")
        service.getExperienceData(
            viewName: "checkout",
            attributes: [:],
            config: nil,
            sendGate: { start in
                guard !sessionReset else { return false }
                start()
                return true
            },
            successLayout: { _ in XCTFail("unexpected success") },
            failure: { error, statusCode, _ in
                XCTAssertEqual(error as? OffersService.OffersError, .discardedBeforeSend)
                XCTAssertNil(statusCode, "a discard carries no status code")
                discarded.fulfill()
            }
        )

        wait(for: [discarded], timeout: 5)
        XCTAssertEqual(stub.requestCount, 1, "the departing customer's attributes and token are not sent again")
    }

    /// The gate is asked at the hand-off, with the send as its action: the request leaves only when the gate runs
    /// that action, and a gate that declines leaves the transport untouched and fails the placement as a discard.
    func test_getExperienceData_sendGateEnclosesTheHandOff_sendsOnlyWhenTheGateRunsIt() {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let service = makeService(stub)

        // Declined: the gate is asked once, does not run the send, and nothing reaches the transport.
        var declinedGateAsked = 0
        let discarded = expectation(description: "a declined hand-off fails as a discard")
        service.getExperienceData(
            viewName: "checkout",
            attributes: [:],
            config: nil,
            sendGate: { _ in
                declinedGateAsked += 1
                return false
            },
            successLayout: { _ in XCTFail("unexpected success") },
            failure: { error, statusCode, _ in
                XCTAssertEqual(error as? OffersService.OffersError, .discardedBeforeSend)
                XCTAssertNil(statusCode, "a discard carries no status code")
                discarded.fulfill()
            }
        )
        wait(for: [discarded], timeout: 5)
        XCTAssertEqual(declinedGateAsked, 1, "a declined hand-off is not retried")
        XCTAssertEqual(stub.requestCount, 0, "nothing reaches the transport when the gate does not run the send")

        // Allowed: the send happens inside the gate's action and nowhere else.
        var requestsBeforeStart: Int?
        var requestsAfterStart: Int?
        let completed = expectation(description: "an allowed hand-off sends the request")
        service.getExperienceData(
            viewName: "checkout",
            attributes: [:],
            config: nil,
            sendGate: { start in
                requestsBeforeStart = stub.requestCount
                start()
                requestsAfterStart = stub.requestCount
                return true
            },
            successLayout: { page in
                XCTAssertNotNil(page)
                completed.fulfill()
            },
            failure: { error, _, _ in XCTFail("unexpected failure: \(error)") }
        )
        wait(for: [completed], timeout: 5)
        XCTAssertEqual(requestsBeforeStart, 0, "the request is not sent before the gate runs the hand-off")
        XCTAssertEqual(requestsAfterStart, 1, "running the hand-off is what sends the request")
        XCTAssertEqual(stub.requestCount, 1)
    }

    private func makeOffersClient(_ stub: StubHTTPClient) -> OffersClient {
        makeOffersClient(httpClient: stub)
    }

    private func makeOffersClient(httpClient: HTTPClientAdapter) -> OffersClient {
        OffersClient(
            baseURL: URL(string: Environment.Prod.gatewayBaseURL)!,
            accountId: "account-1",
            authToken: nil,
            sdkVersion: "1.0.0",
            layoutSchemaVersion: "1",
            pageInstanceGuid: "page-instance-guid",
            httpClient: httpClient
        )
    }

    /// A real `RoktHTTPClient` whose transport is the URL protocol stub and whose body encoder is `bodyEncoder`, so a
    /// test drives the production build of the request and reads what the transport was given.
    private func makeRealClient(bodyEncoder: RoktHTTPParameterEncoder) -> RoktHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoktHTTPUrlProtocolStub.self]
        return RoktHTTPClient(sessionConfiguration: configuration, encoders: [RoktHTTPURLEncoder(), bodyEncoder])
    }

    /// A hand-off that returns without running the send, and without throwing, fails the request itself: nothing
    /// reaches the transport, and the caller is not left waiting for a response that can never arrive.
    func test_fetchOffers_handOffReturnsWithoutRunningTheSend_failsInsteadOfWaiting() async {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let client = makeOffersClient(stub)
        let input = OffersInput(requestId: "request-1", pageIdentifier: "checkout", attributes: [:])

        // Bounded by the expectation's timeout, so a request left waiting fails this test instead of hanging it.
        let failed = expectation(description: "a hand-off that did not run the send fails the request")
        Task {
            do {
                _ = try await client.fetchOffers(input: input) { _ in }
                XCTFail("a hand-off that did not run the send must fail the request")
            } catch {
                XCTAssertEqual(error as? OffersClientError, .handOffDidNotStart)
            }
            failed.fulfill()
        }
        await fulfillment(of: [failed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 0, "nothing reaches the transport when the hand-off does not run the send")
    }

    /// A hand-off that runs the send more than once sends one request, and the request completes once.
    func test_fetchOffers_handOffRunsTheSendTwice_sendsOnceAndCompletesOnce() async throws {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let client = makeOffersClient(stub)
        let input = OffersInput(requestId: "request-1", pageIdentifier: "checkout", attributes: [:])

        let (_, response) = try await client.fetchOffers(input: input) { start in
            start()
            start()
        }

        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(stub.requestCount, 1, "running the send a second time sends nothing more")
    }

    // MARK: - The request is built before the hand-off, through the real client

    /// The request — its URL, its headers and the JSON encoding of its body — is built before the hand-off is asked,
    /// and never inside it, so a caller that holds a lock across the hand-off holds it only for the send.
    func test_fetchOffers_encodesTheBodyBeforeTheHandOffIsEntered_neverInsideIt() async throws {
        RoktHTTPUrlProtocolStub.stub(data: Data(offersResponse.utf8), response: anyHTTPURLResponse(), error: nil)
        let encoder = RecordingBodyEncoder()
        let client = makeOffersClient(httpClient: makeRealClient(bodyEncoder: encoder))
        let input = OffersInput(requestId: "request-1", pageIdentifier: "checkout", attributes: ["email": "a@b.com"])

        let lock = NSLock()
        var order: [String] = []
        var insideHandOff = false
        var encodedInsideHandOff = false
        encoder.onEncode = {
            lock.lock()
            defer { lock.unlock() }
            order.append("encode")
            if insideHandOff { encodedInsideHandOff = true }
        }

        let (_, response) = try await client.fetchOffers(input: input) { start in
            lock.lock()
            insideHandOff = true
            order.append("hand-off")
            lock.unlock()
            start()
            lock.lock()
            insideHandOff = false
            lock.unlock()
        }

        XCTAssertEqual(response?.statusCode, 200)
        lock.lock()
        defer { lock.unlock() }
        XCTAssertEqual(order, ["encode", "hand-off"], "the body is encoded before the hand-off is entered")
        XCTAssertFalse(encodedInsideHandOff, "nothing is encoded inside the hand-off")
    }

    /// The default hand-off sends exactly one request, and it is the offers request as the real client and its real
    /// body encoder build it: the URL, the method, the exact header set and a body carrying the attributes.
    func test_fetchOffers_defaultHandOff_sendsOneRequestWithTheExpectedURLHeadersAndBody() async throws {
        RoktHTTPUrlProtocolStub.stub(data: Data(offersResponse.utf8), response: anyHTTPURLResponse(), error: nil)
        var client = makeOffersClient(httpClient: makeRealClient(bodyEncoder: RoktHTTPBodyEncoder()))
        client.deviceHeaders = ["rokt-os-type": "iOS"]
        let input = OffersInput(requestId: "request-1", pageIdentifier: "checkout", attributes: ["email": "a@b.com"])

        let lock = NSLock()
        var sent: [SentRequest] = []
        RoktHTTPUrlProtocolStub.observeRequests { request in
            lock.lock()
            defer { lock.unlock() }
            sent.append(SentRequest(request))
        }

        let (_, response) = try await client.fetchOffers(input: input)

        XCTAssertEqual(response?.statusCode, 200)
        lock.lock()
        defer { lock.unlock() }
        XCTAssertEqual(sent.count, 1, "the default hand-off sends once")
        let request = try XCTUnwrap(sent.first)
        XCTAssertEqual(request.url, URL(string: "https://apps.rokt.com/v2/sessions/offers"))
        XCTAssertEqual(request.method, "POST")
        // No Authorization without a token, and no Accept: the body encoder adds none when Content-Type is set.
        XCTAssertEqual(request.headers, [
            "rokt-account-id": "account-1",
            "content-type": "application/json",
            "x-request-id": "request-1",
            "rokt-page-instance-guid": "page-instance-guid",
            "rokt-layout-schema-version": "1",
            "rokt-os-type": "iOS"
        ], "the header set is exactly the offers request's")
        let expectedBody = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SelectRequest(
            page: SelectPage(pageIdentifier: "checkout"),
            channel: SelectChannel(sdkVersion: "1.0.0"),
            attributes: ["email": "a@b.com"]
        ))) as? NSDictionary
        XCTAssertNotNil(expectedBody)
        XCTAssertEqual(request.body, expectedBody, "the body is the encoded offers request")
        XCTAssertEqual((request.body?["attributes"] as? [String: String])?["email"], "a@b.com")
    }

    /// A hand-off that declines after the request was built sends nothing: the built request is dropped with the
    /// refusal and the caller receives the hand-off's error, never a response.
    func test_fetchOffers_handOffDeclinesAfterTheRequestWasBuilt_sendsNothing() async {
        RoktHTTPUrlProtocolStub.stub(data: Data(offersResponse.utf8), response: anyHTTPURLResponse(), error: nil)
        let encoder = RecordingBodyEncoder()
        let client = makeOffersClient(httpClient: makeRealClient(bodyEncoder: encoder))
        let input = OffersInput(requestId: "request-1", pageIdentifier: "checkout", attributes: ["email": "a@b.com"])

        var encoded = false
        encoder.onEncode = { encoded = true }
        // A request the transport were given would be observed on the session's queue, so the check that none was is
        // an inverted expectation over a bounded window.
        let nothingSent = expectation(description: "nothing reaches the transport when the hand-off declines")
        nothingSent.isInverted = true
        RoktHTTPUrlProtocolStub.observeRequests { _ in nothingSent.fulfill() }

        do {
            _ = try await client.fetchOffers(input: input) { _ in throw OffersService.OffersError.discardedBeforeSend }
            XCTFail("a declined hand-off must fail the request")
        } catch {
            XCTAssertEqual(error as? OffersService.OffersError, .discardedBeforeSend)
        }

        XCTAssertTrue(encoded, "the request was built before the hand-off was asked")
        await fulfillment(of: [nothingSent], timeout: 0.5)
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

    func test_getExperienceData_onUnauthorized_dropsSessionAndFails() async {
        // First 200 rolls a live token forward; the second call sends it, gets 401, so the
        // session is dropped and the failure surfaces — no inline re-mint (the next offers call
        // would send no token and re-mint a fresh session).
        let stub = StubHTTPClient(responses: [
            (Data(offersResponse.utf8), 200), // call 1: roll a live token forward
            (nil, 401) // call 2: token rejected
        ])
        let sessionManager = TxnSessionManager()
        let service = makeService(stub, sessionManager: sessionManager)

        let first = expectation(description: "first call rolls token")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            first.fulfill()
        }, failure: { error, _, _ in XCTFail("unexpected failure: \(error)") })
        await fulfillment(of: [first], timeout: 5)

        let failed = expectation(description: "401 drops session and fails")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, statusCode, _ in
            XCTAssertEqual(statusCode, 401)
            failed.fulfill()
        })
        await fulfillment(of: [failed], timeout: 5)

        // No inline re-mint: only the original call + the 401 call.
        XCTAssertEqual(stub.requestCount, 2)
        // Session was cleared, so a subsequent offers call would send no Authorization and re-mint.
        let header = await sessionManager.authorizationHeader
        XCTAssertNil(header)
    }
}
