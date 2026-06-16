import XCTest
@testable import Rokt_Widget

final class TestTxnInitWiring: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: StubInitHTTPClient!
    // Retains the session manager handed to the override service so a test can
    // assert what `performInit` seeded into the manager init actually uses.
    private var capturedSessionManager: TxnSessionManager?

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = StubInitHTTPClient()
        capturedSessionManager = nil
    }

    override func tearDown() {
        impl = nil
        stub = nil
        capturedSessionManager = nil
        super.tearDown()
    }

    private func injectService() {
        impl.makeTxnInitServiceOverride = { [stub] tagId in
            TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                layoutSchemaVersion: "1.0",
                sessionManager: TxnSessionManager(),
                httpClient: stub!,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
    }

    // Same seam as injectService(), but retains the manager so shared-session
    // seeding done by performInit can be inspected directly.
    private func injectServiceCapturingManager() {
        impl.makeTxnInitServiceOverride = { [weak self, stub] tagId in
            let sessionManager = TxnSessionManager()
            self?.capturedSessionManager = sessionManager
            return TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                layoutSchemaVersion: "1.0",
                sessionManager: sessionManager,
                httpClient: stub!,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
    }

    private func waitUntil(_ condition: @escaping () -> Bool, timeout: TimeInterval = 2) {
        let exp = expectation(description: "condition met")
        func check() {
            if condition() {
                exp.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: check)
            }
        }
        check()
        wait(for: [exp], timeout: timeout)
    }

    func test_v2InitSuccess_setsInitializedAndBridgesFeatureFlags() {
        stub.result = .success(data: Data(
            """
            {
              "session_id": "sess-1",
              "session_token": { "token": "jwt", "expires_at": 32503680000000 },
              "feature_flags": { "rokt-tracking-status": true, "client-timeout-ms": 30000 },
              "fonts": []
            }
            """.utf8
        ))
        injectService()

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertTrue(impl.initFeatureFlags.isEnabled(.roktTrackingStatus))
    }

    func test_v2InitFailure_leavesSdkUninitialized() {
        stub.result = .status(400)
        injectService()

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        // Give the async path time to run before asserting it did not initialize.
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertFalse(impl.isInitialized)
    }

    // MARK: - Shared session seeding at init

    func test_pendingSharedSession_isSeededIntoInitsSessionManager() {
        // A live bundle set before init must be adopted by the manager init uses,
        // so its bearer token rides /v2/sessions/init and the gateway continues
        // the SAME session. A 400 keeps the server from overwriting the seed, so
        // the assertion isolates the seeding step.
        impl.setSharedSession(RoktSharedSession(
            sessionId: "web-sid",
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))
        stub.result = .status(400)
        injectServiceCapturingManager()

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        // performInit seeds synchronously before the async request, so the manager
        // and the public export reflect the seeded session immediately.
        XCTAssertEqual(capturedSessionManager?.currentSessionId, "web-sid")
        XCTAssertEqual(capturedSessionManager?.authorizationHeader, "Bearer web-jwt")
        XCTAssertEqual(impl.getSharedSession()?.sessionId, "web-sid")
        XCTAssertEqual(impl.getSharedSession()?.token, "web-jwt")
    }

    func test_expiredPendingSharedSession_isIgnored_soInitMintsAFreshSession() {
        // An expired bundle is dropped at seeding (a dead token is useless), so the
        // manager has no bearer and init proceeds to mint a brand-new session.
        impl.setSharedSession(RoktSharedSession(
            sessionId: "web-sid",
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: -1)
        ))
        stub.result = .success(data: Data(
            """
            {
              "session_id": "sess-1",
              "session_token": { "token": "jwt", "expires_at": 32503680000000 },
              "feature_flags": {},
              "fonts": []
            }
            """.utf8
        ))
        injectServiceCapturingManager()

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        // The expired seed never landed, so before the response there is no session.
        XCTAssertNil(capturedSessionManager?.currentSessionId)

        // Init mints a fresh session; the seeded id is nowhere to be found.
        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(capturedSessionManager?.currentSessionId, "sess-1")
        XCTAssertEqual(impl.getSharedSession()?.sessionId, "sess-1")
        XCTAssertNotEqual(impl.getSharedSession()?.sessionId, "web-sid")
    }
}

private final class StubInitHTTPClient: HTTPClientAdapter {
    enum Result {
        case success(data: Data)
        case status(Int)
    }

    var result: Result = .status(500)

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
