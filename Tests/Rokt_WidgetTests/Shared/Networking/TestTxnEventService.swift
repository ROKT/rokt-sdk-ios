import XCTest
@testable import Rokt_Widget

final class TestTxnEventService: XCTestCase {

    private var now: Date!
    private var sessionManager: TxnSessionManager!
    private var httpClient: MockTxnEventsHTTPClient!

    override func setUp() {
        super.setUp()
        now = Date(timeIntervalSince1970: 1_000_000)
        sessionManager = TxnSessionManager(clock: { self.now })
        httpClient = MockTxnEventsHTTPClient()
    }

    override func tearDown() {
        now = nil
        sessionManager = nil
        httpClient = nil
        super.tearDown()
    }

    private func makeService(
        environment: Environment = .Prod,
        deviceHeaders: [String: String] = ["rokt-os-type": "iOS"],
        maxRetries: Int = 3,
        pendingStore: TxnPendingEventStoring? = nil,
        sleep: @escaping (TimeInterval) async throws -> Void = { _ in }
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
            sleep: sleep
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

        try await makeService(deviceHeaders: [
            "rokt-os-type": "iOS",
            "rokt-package-name": "com.rokt.test",
            "rokt-package-version": "1.2.3"
        ]).send(events: sampleEvents())

        XCTAssertEqual(httpClient.capturedHeaders.first?["Authorization"], "Bearer stored-jwt")
        XCTAssertEqual(httpClient.capturedHeaders.first?["rokt-account-id"], "account-1")
        XCTAssertEqual(httpClient.capturedHeaders.first?["rokt-os-type"], "iOS")
        XCTAssertEqual(httpClient.capturedHeaders.first?["rokt-package-name"], "com.rokt.test")
        XCTAssertEqual(httpClient.capturedHeaders.first?["rokt-package-version"], "1.2.3")
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

    func test_send_retriesOn429_thenSucceeds() async throws {
        httpClient.results = [.status(429), .success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        XCTAssertEqual(httpClient.callCount, 2)
    }

    func test_send_retriesOn408_thenSucceeds() async throws {
        httpClient.results = [.status(408), .success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        XCTAssertEqual(httpClient.callCount, 2)
    }

    func test_send_honorsRetryAfterHeader_overExponentialBackoff() async throws {
        var recordedDelays: [TimeInterval] = []
        let service = makeService(sleep: { recordedDelays.append($0) })
        httpClient.results = [.statusWithHeaders(429, ["Retry-After": "2"]),
                              .success(status: 202, data: rotatedResponse())]

        try await service.send(events: sampleEvents())

        XCTAssertEqual(httpClient.callCount, 2)
        XCTAssertEqual(recordedDelays, [2.0])
    }

    func test_send_retryAfterMalformed_fallsBackToBackoff() async throws {
        var recordedDelays: [TimeInterval] = []
        let service = makeService(sleep: { recordedDelays.append($0) })
        // Non-numeric (HTTP-date) Retry-After is not honored; backoff is used instead.
        // baseBackoff is 0 in tests, so the fallback delay is 0 rather than the header value.
        httpClient.results = [.statusWithHeaders(503, ["Retry-After": "Wed, 21 Oct 2025 07:28:00 GMT"]),
                              .success(status: 202, data: rotatedResponse())]

        try await service.send(events: sampleEvents())

        XCTAssertEqual(httpClient.callCount, 2)
        XCTAssertEqual(recordedDelays, [0.0])
    }

    func test_send_retriesOnTimeout_thenSucceeds() async throws {
        httpClient.results = [.transport(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
                              .success(status: 202, data: rotatedResponse())]

        try await makeService().send(events: sampleEvents())

        XCTAssertEqual(httpClient.callCount, 2)
    }

    func test_send_retriesWhenOffline_thenSucceeds() async throws {
        // A device that is offline surfaces NSURLErrorNotConnectedToInternet; treat it as a
        // transient transport failure so the batch is retried rather than dropped.
        httpClient.results = [.transport(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)),
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

    func test_send_unauthorized_dropsSessionAndDoesNotRetry() async {
        await storeValidToken()
        // A 401 is a forged/corrupted token (the recoverable expired case returns 200), so it is
        // not retried: the batch is dropped and the bad session cleared.
        httpClient.results = [.status(401)]

        do {
            try await makeService().send(events: sampleEvents())
            XCTFail("Expected send to fail on 401")
        } catch let error as TxnEventService.TxnEventError {
            XCTAssertEqual(error, .unexpectedStatusCode(401))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let header = await sessionManager.authorizationHeader
        let sessionId = await sessionManager.currentSessionId
        XCTAssertNil(header)
        XCTAssertNil(sessionId)
        XCTAssertEqual(httpClient.callCount, 1)
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

    func test_send_exhaustedRecoverableFailure_persistsBatchForReplay() async {
        let store = SpyTxnPendingEventStore()
        httpClient.results = [.status(503)]

        do {
            try await makeService(pendingStore: store).send(events: sampleEvents())
            XCTFail("Expected send to fail after exhausting retries")
        } catch {
            XCTAssertEqual(store.persistedBatches.count, 1)
            XCTAssertEqual(store.persistedBatches.first?.first?.instanceId, "instance-1")
        }
    }

    func test_send_nonRetryableFailure_doesNotPersist() async {
        let store = SpyTxnPendingEventStore()
        httpClient.results = [.status(400)]

        do {
            try await makeService(pendingStore: store).send(events: sampleEvents())
            XCTFail("Expected send to fail on 400")
        } catch {
            XCTAssertTrue(store.persistedBatches.isEmpty)
        }
    }

    func test_send_unauthorized_doesNotPersist() async {
        await storeValidToken()
        let store = SpyTxnPendingEventStore()
        httpClient.results = [.status(401)]

        do {
            try await makeService(pendingStore: store).send(events: sampleEvents())
            XCTFail("Expected send to fail on 401")
        } catch {
            XCTAssertTrue(store.persistedBatches.isEmpty)
        }
    }

    func test_send_success_doesNotPersist() async throws {
        let store = SpyTxnPendingEventStore()
        httpClient.results = [.success(status: 202, data: rotatedResponse())]

        try await makeService(pendingStore: store).send(events: sampleEvents())

        XCTAssertTrue(store.persistedBatches.isEmpty)
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

private final class SpyTxnPendingEventStore: TxnPendingEventStoring {
    private(set) var persistedBatches: [[TxnEvent]] = []
    var batchesToDrain: [[TxnEvent]] = []

    func persist(events: [TxnEvent]) {
        persistedBatches.append(events)
    }

    func drainValid() -> [[TxnEvent]] {
        defer { batchesToDrain = [] }
        return batchesToDrain
    }
}
