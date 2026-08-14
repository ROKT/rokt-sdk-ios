import XCTest
@testable import Rokt_Widget

final class TestInitRecovery: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: StubRecoveryInitHTTPClient!

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = StubRecoveryInitHTTPClient()
        impl.makeTxnInitServiceOverride = { [stub] tagId in
            TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.3.2",
                layoutSchemaVersion: "1.0",
                httpClient: stub!,
                maxRetries: 0,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
        impl.initRecoveryScheduler = { _, work in DispatchQueue.main.async(execute: work) }
    }

    override func tearDown() {
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
        XCTAssertEqual(events, [false, true])
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
        stub.results = [.status(429), .status(429), .status(429), .status(429), .status(429)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        settle()
        XCTAssertFalse(impl.isInitialized)
        XCTAssertEqual(stub.requestCount, 4, "initial attempt plus three bounded recoveries")
    }

    func test_initRecovery_counterResetsOnFreshInit() {
        stub.results = [.status(429), .status(429), .status(429), .status(429), .status(429)]
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 4)

        stub.results = [.status(429), .success(data: Self.successBody)]
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(stub.requestCount, 6)
    }

    // The guards inside the scheduled block only matter while an attempt is in flight, which the
    // default immediate scheduler can never produce. These two hold the attempt instead of running
    // it, change the state underneath it, and only then let it go.
    func test_initRecovery_supersededAttemptDoesNotReinitialise() {
        var pending: [() -> Void] = []
        impl.initRecoveryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(429), .status(400)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertEqual(pending.count, 1, "a 429 schedules a recovery")

        // A fresh init supersedes the held attempt, and fails permanently so nothing new is queued.
        impl.initWith(roktTagId: "tag-2", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 2)
        XCTAssertEqual(pending.count, 1, "a 400 must not schedule a recovery")

        pending.forEach { $0() }
        settle()
        XCTAssertEqual(stub.requestCount, 2, "the superseded generation must not re-init")
        XCTAssertFalse(impl.isInitialized)
    }

    func test_initRecovery_scheduledAttemptIsSkippedOnceInitHasSucceeded() {
        var pending: [() -> Void] = []
        impl.initRecoveryScheduler = { _, work in pending.append(work) }
        stub.results = [.status(503)]

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        settle()
        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertEqual(pending.count, 1)

        // Init has since succeeded by another route, so the held attempt is redundant.
        impl.isInitialized = true
        pending.forEach { $0() }
        settle()
        XCTAssertEqual(stub.requestCount, 1, "a recovery must not re-init once init has succeeded")
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
