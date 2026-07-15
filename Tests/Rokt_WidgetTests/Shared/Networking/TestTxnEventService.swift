import XCTest
@testable import Rokt_Widget

final class TestTxnEventService: XCTestCase {

    private var now: Date!
    private var sessionManager: TxnSessionManager!
    private var httpClient: MockTxnEventsHTTPClient!
    // Isolated per test so the shared singleton never leaks events across cases.
    private var pendingStore: TxnPendingEventsStore!

    override func setUp() {
        super.setUp()
        now = Date(timeIntervalSince1970: 1_000_000)
        sessionManager = TxnSessionManager(clock: { self.now })
        httpClient = MockTxnEventsHTTPClient()
        pendingStore = TxnPendingEventsStore()
    }

    override func tearDown() {
        now = nil
        sessionManager = nil
        httpClient = nil
        pendingStore = nil
        super.tearDown()
    }

    private func makeService(
        environment: Environment = .Prod,
        deviceHeaders: [String: String] = ["rokt-os-type": "iOS"],
        maxRetries: Int = 3
    ) -> TxnEventService {
        TxnEventService(
            environment: environment,
            accountId: "account-1",
            sdkVersion: "5.2.2",
            sessionManager: sessionManager,
            httpClient: httpClient,
            deviceHeaders: deviceHeaders,
            maxRetries: maxRetries,
            baseBackoff: 0,
            pendingStore: pendingStore,
            sleep: { _ in }
        )
    }

    private func storeValidToken(_ token: String = "stored-jwt") async {
        let expiryMs = Int64(now.addingTimeInterval(1800).timeIntervalSince1970 * 1000)
        await sessionManager.update(sessionId: "session-1", sessionToken: TxnSessionToken(token: token, expiresAt: expiryMs))
    }

    private func rotatedResponse(token: String = "rotated-jwt") -> Data {
        let expiryMs = Int64(now.addingTimeInterval(3600).timeIntervalSince1970 * 1000)
        return Data(
            """
            {
              "session_token": { "token": "\(token)", "expires_at": \(expiryMs) },
              "event_ids": ["event-1"]
            }
            """.utf8
        )
    }

    private func sampleEvents() -> [TxnEvent] {
        [TxnEvent(eventType: "impression", instanceId: "instance-1", timestamp: 1_700_000_000_000, data: ["k": "v"])]
    }

    func test_send_success_rotatesSessionToken() async throws {
        await storeValidToken()
        httpClient.results = [.success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        let header = await sessionManager.authorizationHeader
        XCTAssertEqual(header, "Bearer rotated-jwt")
        XCTAssertEqual(httpClient.callCount, 1)
    }

    func test_send_withValidToken_attachesAuthorizationAndDeviceHeaders() async throws {
        await storeValidToken()
        httpClient.results = [.success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        XCTAssertEqual(httpClient.capturedHeaders.first?["Authorization"], "Bearer stored-jwt")
        XCTAssertEqual(httpClient.capturedHeaders.first?["rokt-account-id"], "account-1")
        XCTAssertEqual(httpClient.capturedHeaders.first?["rokt-os-type"], "iOS")
        XCTAssertNil(httpClient.capturedHeaders.first?["rokt-txn-shadow"])
    }

    func test_send_withoutToken_omitsAuthorization() async throws {
        httpClient.results = [.success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        XCTAssertNil(httpClient.capturedHeaders.first?["Authorization"])
    }

    func test_send_responseWithoutSessionToken_leavesTokenUnchanged() async throws {
        await storeValidToken("keep-jwt")
        httpClient.results = [.success(status: 202, data: Data(#"{ "event_ids": ["event-1"] }"#.utf8))]

        try await makeService().send(events: sampleEvents())

        let header = await sessionManager.authorizationHeader
        XCTAssertEqual(header, "Bearer keep-jwt")
    }

    func test_send_retriesOnTransient5xx_thenSucceeds() async throws {
        httpClient.results = [.status(500), .status(503), .success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        XCTAssertEqual(httpClient.callCount, 3)
    }

    func test_send_retriesOnTimeout_thenSucceeds() async throws {
        httpClient.results = [.transport(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
                              .success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        XCTAssertEqual(httpClient.callCount, 2)
    }

    func test_send_exhaustsRetries_throwsUnexpectedStatus() async {
        httpClient.results = [.status(503)]

        do {
            try await makeService(maxRetries: 3).send(events: sampleEvents())
            XCTFail("Expected send to fail after exhausting retries")
        } catch let error as TxnEventService.TxnEventError {
            XCTAssertEqual(error, .unexpectedStatusCode(503))
            XCTAssertEqual(httpClient.callCount, 4)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_send_nonRetryableStatus_doesNotRetry() async {
        httpClient.results = [.status(400)]

        do {
            try await makeService().send(events: sampleEvents())
            XCTFail("Expected send to fail on 400")
        } catch let error as TxnEventService.TxnEventError {
            XCTAssertEqual(error, .unexpectedStatusCode(400))
            XCTAssertEqual(httpClient.callCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_send_unauthorized_buffersEventsAndClearsSession() async throws {
        await storeValidToken()
        httpClient.results = [.status(401)]

        // Best-effort: a 401 no longer throws — it drops the session and buffers the events.
        try await makeService().send(events: sampleEvents())

        // The session is dropped so the next offers call re-mints a fresh one.
        let header = await sessionManager.authorizationHeader
        let sessionId = await sessionManager.currentSessionId
        XCTAssertNil(header)
        XCTAssertNil(sessionId)
        // The events are buffered (not dropped) for re-send under the next session.
        let buffered = await pendingStore.count
        XCTAssertEqual(buffered, 1)
        // 401 is not retried.
        XCTAssertEqual(httpClient.callCount, 1)
    }

    func test_send_afterUnauthorized_reSendsBufferedEventsUnderNewSession() async throws {
        // First send 401s and buffers the event.
        await storeValidToken()
        httpClient.results = [.status(401)]
        try await makeService().send(events: sampleEvents())
        let bufferedAfterFailure = await pendingStore.count
        XCTAssertEqual(bufferedAfterFailure, 1)

        // A fresh session is minted (as an offers call would) and the next send succeeds:
        // the buffered event + the new event are delivered together and the buffer is drained.
        await storeValidToken("fresh-jwt")
        httpClient.results = [.success(status: 202, data: rotatedResponse())]
        try await makeService().send(events: sampleEvents())

        let bufferedAfterFlush = await pendingStore.count
        XCTAssertEqual(bufferedAfterFlush, 0)
        // Second request carried both the buffered and the new event; sent with the fresh token.
        XCTAssertEqual(httpClient.capturedEventCounts.last, 2)
        XCTAssertEqual(httpClient.capturedHeaders.last?["Authorization"], "Bearer fresh-jwt")
    }

    private func events(_ count: Int) -> [TxnEvent] {
        (0..<count).map { index in
            TxnEvent(eventType: "impression", instanceId: "instance-\(index)", timestamp: 1_700_000_000_000, data: ["k": "v"])
        }
    }

    func test_send_chunksEventsIntoBatchesOfMax25() async throws {
        // 60 events -> batches of 25, 25, 10 sent as separate requests.
        try await makeService().send(events: events(60))

        XCTAssertEqual(httpClient.callCount, 3)
        XCTAssertEqual(httpClient.capturedEventCounts, [25, 25, 10])
    }

    func test_send_countAtCap_sendsSingleRequest() async throws {
        try await makeService().send(events: events(TxnEventService.maxEventsPerBatch))

        XCTAssertEqual(httpClient.callCount, 1)
        XCTAssertEqual(httpClient.capturedEventCounts, [TxnEventService.maxEventsPerBatch])
    }

    func test_send_chunkFailure_propagatesAndStopsSubsequentBatches() async {
        // First batch exhausts retries on 400 (non-retryable); later batches must not be sent.
        httpClient.results = [.status(400)]

        do {
            try await makeService().send(events: events(60))
            XCTFail("Expected send to fail on first batch")
        } catch let error as TxnEventService.TxnEventError {
            XCTAssertEqual(error, .unexpectedStatusCode(400))
            XCTAssertEqual(httpClient.callCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_send_emptyEvents_skipsRequest() async throws {
        try await makeService().send(events: [])

        XCTAssertEqual(httpClient.callCount, 0)
    }

    func test_send_invalidBaseURL_throws() async {
        let service = makeService(environment: .custom(baseURL: "ht tp://bad url"))

        do {
            try await service.send(events: sampleEvents())
            XCTFail("Expected invalid base URL to fail")
        } catch let error as TxnEventService.TxnEventError {
            XCTAssertEqual(error, .invalidBaseURL)
            XCTAssertEqual(httpClient.callCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
