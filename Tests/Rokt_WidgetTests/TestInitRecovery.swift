import XCTest
@testable import Rokt_Widget

final class TestInitRecovery: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: StubRecoveryInitHTTPClient!

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = StubRecoveryInitHTTPClient()
        impl.makeTxnInitServiceOverride = { [stub] tagId, _ in
            TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.3.2",
                layoutSchemaVersion: "1.0",
                httpClient: stub!
            )
        }
        impl.initRetryScheduler = { _, work in DispatchQueue.main.async(execute: work) }
    }

    override func tearDown() {
        RoktSDKDateHandler.customDate = nil
        impl = nil
        stub = nil
        super.tearDown()
    }

    private static let successBody = Data(
        """
        {
          "session_id": "sess-1",
          "session_token": { "token": "jwt", "expires_at": 32503680000000 },
          "feature_flags": {},
          "fonts": []
        }
        """.utf8
    )

    func test_initRecovery_retriesAfterRateLimitAndEventuallySucceeds() {
        stub.results = [.status(429), .success(data: Self.successBody)]
        var events: [Bool] = []
        impl.mapEvents(isGlobal: true, onEvent: { event in
            if let initComplete = event as? RoktEvent.InitComplete { events.append(initComplete.success) }
        })

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(events, [true], "the failed first attempt is not reported while a retry is still to come")
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_retriesAfterServerError() {
        stub.results = [.status(503), .success(data: Self.successBody)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_doesNotRetryNonRecoverableStatus() {
        stub.results = [.status(400)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertFalse(impl.isInitialized)
        XCTAssertEqual(stub.requestCount, 1)
    }

    func test_initRecovery_retriesAfterTransientTransportFailure() {
        stub.results = [.transportError(Self.urlError(NSURLErrorNotConnectedToInternet)),
                        .success(data: Self.successBody)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_doesNotRetryPermanentTransportFailure() {
        stub.results = [.transportError(Self.urlError(NSURLErrorCancelled))]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertFalse(impl.isInitialized)
        XCTAssertEqual(stub.requestCount, 1, "a cancelled request fails the same way every time")
    }

    func test_initRecovery_stopsAfterExhaustingAttempts() {
        stub.results = Array(repeating: .status(429), count: 6)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertFalse(impl.isInitialized)
        XCTAssertEqual(stub.requestCount, 5, "the first attempt plus four retries")
    }

    func test_initRecovery_counterResetsOnFreshInit() {
        stub.results = Array(repeating: .status(429), count: 6)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 5)

        stub.results = [.status(429), .success(data: Self.successBody)]
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 7)
    }

    func test_initRecovery_repeatInitWhileRequestInFlight_joinsIt() {
        stub.results = [.success(data: Self.successBody), .success(data: Self.successBody)]

        // The second call lands before the first request has come back.
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        settle()
        XCTAssertEqual(stub.requestCount, 1, "a repeat init for the same tag id must not send a second request")
    }

    func test_initRecovery_repeatInitJustAfterAFailure_isIgnoredWhileTheRetryWaits() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .success(data: Self.successBody)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertEqual(pending.count, 1)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1, "a call within fifteen seconds of the failure leaves the wait alone")
        XCTAssertEqual(pending.count, 1)

        pending.forEach { $0() }
        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_initAfterSuccess_sendsAFreshRequest() {
        stub.results = [.success(data: Self.successBody), .success(data: Self.successBody)]
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 1)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(stub.requestCount, 2, "joining applies only while an init is in flight or waiting")
    }

    func test_initRecovery_initAfterRejectedInit_sendsAFreshRequest() {
        stub.results = [.status(400), .success(data: Self.successBody)]
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2, "a rejected init is over, so a later call must not be joined to it")
    }

    func test_initRecovery_repeatInitForDifferentTagId_isNotJoined() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .success(data: Self.successBody)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)

        impl.initWith(roktTagId: "tag-2", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_worstCaseIsFiveSingleRequests() {
        // Production request settings: one request per attempt, with no quick retries in between.
        impl.makeTxnInitServiceOverride = { [stub] tagId, _ in
            TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.3.2",
                layoutSchemaVersion: "1.0",
                httpClient: stub!
            )
        }
        stub.results = Array(repeating: .transportError(Self.urlError(NSURLErrorTimedOut)), count: 12)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertFalse(impl.isInitialized)
        XCTAssertEqual(stub.requestCount, 5, "one request per attempt, five attempts in all")
    }

    func test_initRecovery_scheduledWaitsGrowAndAreJittered() {
        var delays: [TimeInterval] = []
        impl.initRetryScheduler = { delay, work in
            delays.append(delay)
            DispatchQueue.main.async(execute: work)
        }
        stub.results = Array(repeating: .status(503), count: 6)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(delays.count, 4, "four retries after the first attempt")
        XCTAssertTrue((10.0...12.5).contains(delays[0]), "first wait was \(delays[0])")
        XCTAssertTrue((30.0...37.5).contains(delays[1]), "second wait was \(delays[1])")
        XCTAssertTrue((60.0...75.0).contains(delays[2]), "third wait was \(delays[2])")
        XCTAssertTrue((150.0...187.5).contains(delays[3]), "fourth wait was \(delays[3])")
    }

    func test_initRetryDelay_jitterStretchesEachWaitByAtMostAQuarter() {
        let bases: [TimeInterval] = [10, 30, 60, 150]
        for (attempt, base) in bases.enumerated() {
            XCTAssertEqual(RoktInternalImplementation.initRetryDelay(forAttempt: attempt, jitterUnit: 0), base)
            XCTAssertEqual(RoktInternalImplementation.initRetryDelay(forAttempt: attempt, jitterUnit: 1), base * 1.25)
        }
    }

    func test_initRetryDelay_startsQuicklyAndKeepsGoingForOverFourMinutes() {
        let shortest = (0..<4).map { RoktInternalImplementation.initRetryDelay(forAttempt: $0, jitterUnit: 0) }

        XCTAssertLessThanOrEqual(shortest[0], 10, "the first retry comes quickly, to ride out a blip")
        XCTAssertGreaterThanOrEqual(shortest.reduce(0, +), 250, "the retries must keep going for over four minutes")
    }

    func test_initRecovery_repeatInitAfterFifteenSeconds_runsTheWaitingRetryNow() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .success(data: Self.successBody)]
        let failedAt = Date(timeIntervalSince1970: 1_000_000)
        RoktSDKDateHandler.customDate = failedAt

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertEqual(pending.count, 1)

        // The host calls init again once the network is back, well before the wait would have ended.
        RoktSDKDateHandler.customDate = failedAt.addingTimeInterval(16)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2, "the waiting retry ran at once")

        // The timer that was waiting is now stale and must not send anything.
        pending.forEach { $0() }
        settle()
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_repeatInitBeforeFifteenSeconds_doesNotBringTheRetryForward() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .success(data: Self.successBody)]
        let failedAt = Date(timeIntervalSince1970: 1_000_000)
        RoktSDKDateHandler.customDate = failedAt

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()

        RoktSDKDateHandler.customDate = failedAt.addingTimeInterval(14)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(stub.requestCount, 1, "a call this soon after the failure must not cause another request")
    }

    func test_initRecovery_aListenerThatCallsInitWhenInitFailsForGood_startsAFreshInit() {
        stub.results = [.status(400), .success(data: Self.successBody)]
        var calledAgain = false
        impl.mapEvents(isGlobal: true, onEvent: { [unowned impl = impl!] event in
            if let initComplete = event as? RoktEvent.InitComplete, !initComplete.success, !calledAgain {
                calledAgain = true
                impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
            }
        })

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2, "the init was already over when the listener ran, so its call was not joined")
    }

    func test_initRecovery_firstAttemptUsesTheShortTimeoutAndRetriesTheLongOne() {
        var timeouts: [TimeInterval] = []
        impl.makeTxnInitServiceOverride = { [stub] tagId, timeout in
            timeouts.append(timeout)
            return TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.3.2",
                layoutSchemaVersion: "1.0",
                httpClient: stub!,
                requestTimeout: timeout
            )
        }
        stub.results = Array(repeating: .status(503), count: 6)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(timeouts, [10, 30, 30, 30, 30])
    }

    func test_initRecovery_retriesAfterARequestTimeoutStatus() {
        stub.results = [.status(408), .success(data: Self.successBody)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_repeatInitRightAfterTheTimerFires_joinsTheRetryThatIsNowRunning() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .success(data: Self.successBody), .success(data: Self.successBody)]
        let failedAt = Date(timeIntervalSince1970: 1_000_000)
        RoktSDKDateHandler.customDate = failedAt
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(pending.count, 1)

        // The timer fires and the host calls init in the same moment, well past the minimum gap.
        RoktSDKDateHandler.customDate = failedAt.addingTimeInterval(60)
        pending.forEach { $0() }
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        settle()
        XCTAssertEqual(stub.requestCount, 2, "the timer and the call must not each send a request")
    }

    func test_initRecovery_repeatInitExactlyFifteenSecondsAfterTheFailure_runsTheWaitingRetryNow() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .success(data: Self.successBody)]
        let failedAt = Date(timeIntervalSince1970: 1_000_000)
        RoktSDKDateHandler.customDate = failedAt
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()

        RoktSDKDateHandler.customDate = failedAt.addingTimeInterval(15)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_initRecovery_listenersHearNoFailureWhileARetryIsWaiting() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .success(data: Self.successBody)]
        var events: [Bool] = []
        impl.mapEvents(isGlobal: true, onEvent: { event in
            if let initComplete = event as? RoktEvent.InitComplete { events.append(initComplete.success) }
        })

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()

        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertEqual(pending.count, 1, "a retry is waiting")
        XCTAssertTrue(events.isEmpty, "init has not failed yet, so listeners are not told it did")
        pending.forEach { $0() }
        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(events, [true])
    }

    func test_initRecovery_listenersHearOneFailureOnceTheRetriesAreUsedUp() {
        stub.results = Array(repeating: .status(503), count: 6)
        var events: [Bool] = []
        impl.mapEvents(isGlobal: true, onEvent: { event in
            if let initComplete = event as? RoktEvent.InitComplete { events.append(initComplete.success) }
        })

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(stub.requestCount, 5)
        XCTAssertEqual(events, [false], "one failure, after the last attempt")
    }

    func test_initRecovery_aStaleTimerAfterARunNowCannotRunTheNewWaitingRetry() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503), .status(503), .success(data: Self.successBody)]
        let failedAt = Date(timeIntervalSince1970: 1_000_000)
        RoktSDKDateHandler.customDate = failedAt
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(pending.count, 1)

        // A repeat call runs the waiting retry at once, and that attempt fails too, so a second retry is waiting.
        RoktSDKDateHandler.customDate = failedAt.addingTimeInterval(16)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 2)
        XCTAssertEqual(pending.count, 2)

        // The first timer is stale now: it must not run the retry that the second timer owns.
        pending[0]()
        settle()
        XCTAssertEqual(stub.requestCount, 2)

        pending[1]()
        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 3)
    }

    func test_initRecovery_reportsTheFirstFailureAndTheFinalOneOnly() {
        var reports: [(attempt: String?, final: String?)] = []
        impl.diagnosticsSender = { _, _, info in reports.append((info["attempt"] as? String, info["final"] as? String)) }
        stub.results = Array(repeating: .status(503), count: 6)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(reports.count, 2, "one report when init first fails, one when it gives up")
        XCTAssertEqual(reports.first?.attempt, "1")
        XCTAssertEqual(reports.first?.final, "false")
        XCTAssertEqual(reports.last?.attempt, "5")
        XCTAssertEqual(reports.last?.final, "true")
    }

    func test_initRecovery_reportsATimeout() {
        var reports = 0
        impl.diagnosticsSender = { _, _, _ in reports += 1 }
        stub.results = Array(repeating: .transportError(Self.urlError(NSURLErrorTimedOut)), count: 6)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(reports, 2, "a timeout has no status code and is still reported")
    }

    func test_initRecovery_doesNotReportARateLimit() {
        var reports = 0
        impl.diagnosticsSender = { _, _, _ in reports += 1 }
        stub.results = Array(repeating: .status(429), count: 6)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(reports, 0, "a rate limit is not a fault on this device")
    }

    func test_initRecovery_reportsARejectedInitOnceAsFinal() {
        var reports: [String?] = []
        impl.diagnosticsSender = { _, _, info in reports.append(info["final"] as? String) }
        stub.results = [.status(400)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertEqual(reports, ["true"], "a failure that will not pass is the first and the last")
    }

    func test_initRecovery_supersededAttemptDoesNotReinitialise() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(429), .status(400)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertEqual(pending.count, 1, "a 429 schedules a retry")

        // A fresh init supersedes the held attempt, and fails permanently so nothing new is queued.
        impl.initWith(roktTagId: "tag-2", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 2)
        XCTAssertEqual(pending.count, 1, "a 400 must not schedule a retry")

        pending.forEach { $0() }
        settle()
        XCTAssertEqual(stub.requestCount, 2, "the superseded generation must not re-init")
        XCTAssertFalse(impl.isInitialized)
    }

    func test_initRecovery_scheduledAttemptIsSkippedOnceInitHasSucceeded() {
        var pending: [() -> Void] = []
        impl.initRetryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertEqual(pending.count, 1)

        // Init has since succeeded by another route, so the held attempt is redundant.
        impl.isInitialized = true
        pending.forEach { $0() }
        settle()
        XCTAssertEqual(stub.requestCount, 1, "a retry must not re-init once init has succeeded")
    }

    private static func urlError(_ code: Int) -> NSError {
        NSError(domain: NSURLErrorDomain, code: code)
    }

    private func settle() {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
        wait(for: [settled], timeout: 3)
    }
}

private final class StubRecoveryInitHTTPClient: HTTPClientAdapter {
    enum Result {
        case success(data: Data)
        case status(Int)
        case transportError(NSError)
    }

    var results: [Result] = []
    private(set) var requestCount = 0

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
        let url = URL(string: urlAddress)!
        let result = results.isEmpty ? Result.status(500) : results.removeFirst()
        requestCount += 1

        let httpResult: RoktHTTPRequestResult
        switch result {
        case .success(let data):
            httpResult = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
                responseData: data,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        case .status(let code):
            httpResult = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil),
                responseData: nil,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        case .transportError(let error):
            httpResult = RoktHTTPRequestResult(
                httpURLResponse: nil,
                responseData: nil,
                responseError: error,
                jsonSerialisedResponseData: .success(NSNull())
            )
        }
        completionQueue.async { completionHandler?(httpResult) }
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
