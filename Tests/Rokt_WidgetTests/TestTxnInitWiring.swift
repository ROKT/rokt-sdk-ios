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
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))
        stub.result = .status(400)
        injectServiceCapturingManager()

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        // performInit seeds synchronously before the async request, so the manager
        // and the public export reflect the seeded token immediately. The internal
        // session id stays nil until the gateway's init response populates it.
        XCTAssertEqual(capturedSessionManager?.authorizationHeader, "Bearer web-jwt")
        XCTAssertEqual(impl.getSharedSession()?.token, "web-jwt")
    }

    func test_expiredPendingSharedSession_isIgnored_soInitMintsAFreshSession() {
        // An expired bundle is dropped at seeding (a dead token is useless), so the
        // manager has no bearer and init proceeds to mint a brand-new session.
        impl.setSharedSession(RoktSharedSession(
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

        // Init mints a fresh session; the expired seed's token never rides it.
        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(capturedSessionManager?.currentSessionId, "sess-1")
        XCTAssertEqual(impl.getSharedSession()?.token, "jwt")
        XCTAssertNotEqual(impl.getSharedSession()?.token, "web-jwt")
    }

    // MARK: - Post-init setSharedSession (immediate-adopt branch, ME-04)

    func test_setSharedSession_afterInit_adoptsImmediatelyIntoLiveManager() {
        // A 400 init leaves the SDK uninitialized but still captures the live
        // manager (performInit sets txnSessionManager before the async request).
        // A setSharedSession that follows must take the `if let txnSessionManager`
        // immediate-adopt branch rather than parking a pending seed.
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
        waitUntil { self.impl.isInitialized }

        // Manager now live; this set must land directly in it, overriding the
        // session established by init so the new token is used on the offers API.
        impl.setSharedSession(RoktSharedSession(
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))

        XCTAssertEqual(capturedSessionManager?.authorizationHeader, "Bearer web-jwt")
        XCTAssertEqual(impl.getSharedSession()?.token, "web-jwt")
    }

    // MARK: - getSharedSession before init (ME-03)

    func test_getSharedSession_beforeInit_returnsPendingSeed() {
        // Set-then-get before init must surface the pending bundle, not nil.
        impl.setSharedSession(RoktSharedSession(
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))

        let shared = impl.getSharedSession()
        XCTAssertEqual(shared?.token, "web-jwt")
    }

    func test_getSharedSession_beforeInit_returnsNilForExpiredPendingSeed() {
        // An expired pending seed must report nothing (honour expiry), matching
        // the live manager's behaviour.
        impl.setSharedSession(RoktSharedSession(
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: -1)
        ))

        XCTAssertNil(impl.getSharedSession())
    }

    // MARK: - Blank credential rejection at the impl layer (ME-01)

    func test_setSharedSession_rejectsBlankToken_soNothingIsPending() {
        impl.setSharedSession(RoktSharedSession(
            token: "",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))
        XCTAssertNil(impl.getSharedSession())
    }

    // MARK: - Re-init carry-forward (ME-02)

    func test_reInit_carriesForwardLiveSessionWhenNoPendingSeed() {
        // First init mints a live session (sess-1). A re-init with no pending seed
        // must carry that live session into the new manager instead of dropping it
        // and re-minting from scratch.
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
        waitUntil { self.impl.isInitialized }
        XCTAssertEqual(capturedSessionManager?.currentSessionId, "sess-1")

        // Re-init: a fresh manager is captured. The carry-forward must seed it with
        // the prior live session before the new init response lands. A 400 on the
        // re-init keeps the server from overwriting, isolating the carry-forward.
        stub.result = .status(400)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        // performInit carries forward synchronously before the async request.
        // The carry-forward propagates the bearer token (the continuity
        // credential); the internal session id rides inside the token's JWT
        // `sub` and is repopulated by the next gateway init response, so it is
        // nil here on the 400-isolated re-init.
        XCTAssertEqual(capturedSessionManager?.authorizationHeader, "Bearer jwt")
        XCTAssertEqual(impl.getSharedSession()?.token, "jwt")
    }

    // MARK: - Concurrency smoke test for the set/init handshake (HI-01)

    func test_concurrentSetSharedSessionAndInit_doesNotCrashOrDropSeedIntoNoMansLand() {
        // Drives setSharedSession and initWith from different threads to exercise
        // the lock around the pending-seed/manager handshake. The harness cannot
        // deterministically pin the interleaving, but the lock must keep state
        // consistent (no crash / torn reads) and the seed must end up either in
        // the manager or surfaced by getSharedSession — never silently lost.
        stub.result = .status(400)
        injectServiceCapturingManager()

        let setExp = expectation(description: "set done")
        let initStarted = expectation(description: "init issued")

        DispatchQueue.global().async {
            self.impl.setSharedSession(RoktSharedSession(
                token: "web-jwt",
                expiresAt: Date(timeIntervalSinceNow: 1800)
            ))
            setExp.fulfill()
        }
        // initWith touches main-affine state, so issue it on main.
        DispatchQueue.main.async {
            self.impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
            initStarted.fulfill()
        }

        wait(for: [setExp, initStarted], timeout: 2)

        // Let any async work settle, then assert the seed is reachable somewhere.
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 2)

        let managerHasSeed = capturedSessionManager?.authorizationHeader == "Bearer web-jwt"
        let exportHasSeed = impl.getSharedSession()?.token == "web-jwt"
        XCTAssertTrue(managerHasSeed || exportHasSeed,
                      "the concurrently-set shared session must not be silently dropped")
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
