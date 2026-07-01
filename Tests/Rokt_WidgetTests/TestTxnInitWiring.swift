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

    // Polls an async condition until it holds or the timeout elapses. Needed
    // because TxnSessionManager is an actor: performInit seeds it from a Task,
    // so a seed applied during init lands asynchronously rather than before
    // initWith returns.
    private func asyncWaitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let met = await condition()
        XCTAssertTrue(met, "condition not met within \(timeout)s")
    }

    // MARK: - Shared session seeding at init

    func test_pendingSharedSession_isSeededIntoInitsSessionManager() async {
        // A live bundle set before init must be adopted by the manager init uses,
        // so its bearer token rides /v2/sessions/init and the gateway continues
        // the SAME session. A 400 keeps the server from overwriting the seed, so
        // the assertion isolates the seeding step.
        await impl.setSharedSession(RoktSharedSession(
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))
        stub.result = .status(400)
        injectServiceCapturingManager()

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        // performInit seeds the manager from a Task ahead of the request, so poll
        // until the seeded bearer lands. The internal session id stays nil until
        // the gateway's init response populates it.
        await asyncWaitUntil { await self.capturedSessionManager?.authorizationHeader == "Bearer web-jwt" }
        let token = await impl.getSharedSession()?.token
        XCTAssertEqual(token, "web-jwt")
    }

    func test_expiredPendingSharedSession_isIgnored_soInitMintsAFreshSession() async {
        // An expired bundle is dropped at seeding (a dead token is useless), so the
        // manager has no bearer and init proceeds to mint a brand-new session.
        await impl.setSharedSession(RoktSharedSession(
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

        // Init mints a fresh session; the expired seed's token never rides it.
        waitUntil { self.impl.isInitialized }
        let sessionId = await capturedSessionManager?.currentSessionId
        let token = await impl.getSharedSession()?.token
        XCTAssertEqual(sessionId, "sess-1")
        XCTAssertEqual(token, "jwt")
        XCTAssertNotEqual(token, "web-jwt")
    }

    // MARK: - Post-init setSharedSession (immediate-adopt branch, ME-04)

    func test_setSharedSession_afterInit_adoptsImmediatelyIntoLiveManager() async {
        // Init captures the live manager and mints sess-1/jwt. A setSharedSession
        // that follows must take the immediate-adopt branch (live manager present)
        // rather than parking a pending seed, overriding the session init set so
        // the new token is used on the offers API.
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

        // awaiting set guarantees the seed has landed in the live manager.
        await impl.setSharedSession(RoktSharedSession(
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))

        let header = await capturedSessionManager?.authorizationHeader
        let token = await impl.getSharedSession()?.token
        XCTAssertEqual(header, "Bearer web-jwt")
        XCTAssertEqual(token, "web-jwt")
    }

    // MARK: - getSharedSession before init (ME-03)

    func test_getSharedSession_beforeInit_returnsPendingSeed() async {
        // Set-then-get before init must surface the pending bundle, not nil.
        await impl.setSharedSession(RoktSharedSession(
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))

        let shared = await impl.getSharedSession()
        XCTAssertEqual(shared?.token, "web-jwt")
    }

    func test_getSharedSession_beforeInit_returnsNilForExpiredPendingSeed() async {
        // An expired pending seed must report nothing (honour expiry), matching
        // the live manager's behaviour.
        await impl.setSharedSession(RoktSharedSession(
            token: "web-jwt",
            expiresAt: Date(timeIntervalSinceNow: -1)
        ))

        let shared = await impl.getSharedSession()
        XCTAssertNil(shared)
    }

    // MARK: - Blank credential rejection at the impl layer (ME-01)

    func test_setSharedSession_rejectsBlankToken_soNothingIsPending() async {
        await impl.setSharedSession(RoktSharedSession(
            token: "",
            expiresAt: Date(timeIntervalSinceNow: 1800)
        ))
        let shared = await impl.getSharedSession()
        XCTAssertNil(shared)
    }

    // MARK: - Re-init carry-forward (ME-02)

    func test_reInit_carriesForwardLiveSessionWhenNoPendingSeed() async {
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
        let firstSessionId = await capturedSessionManager?.currentSessionId
        XCTAssertEqual(firstSessionId, "sess-1")

        // Re-init: a fresh manager is captured. The carry-forward must seed it with
        // the prior live session. A 400 on the re-init keeps the server from
        // overwriting, isolating the carry-forward. The carry-forward propagates
        // the bearer token (the continuity credential); the session id rides inside
        // the token's JWT `sub` and is repopulated by the next gateway init response.
        stub.result = .status(400)
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        await asyncWaitUntil { await self.capturedSessionManager?.authorizationHeader == "Bearer jwt" }
        let token = await impl.getSharedSession()?.token
        XCTAssertEqual(token, "jwt")
    }

    // MARK: - Concurrency smoke test for the set/init handshake (HI-01)

    func test_concurrentSetSharedSessionAndInit_doesNotCrashOrDropSeedIntoNoMansLand() async {
        // Drives setSharedSession and initWith concurrently to exercise the lock
        // around the pending-seed/manager handshake. The harness cannot
        // deterministically pin the interleaving, but the lock must keep state
        // consistent (no crash / torn reads) and the seed must end up either in
        // the manager or surfaced by getSharedSession — never silently lost.
        stub.result = .status(400)
        injectServiceCapturingManager()

        let setTask = Task {
            await self.impl.setSharedSession(RoktSharedSession(
                token: "web-jwt",
                expiresAt: Date(timeIntervalSinceNow: 1800)
            ))
        }
        // initWith touches main-affine state, so issue it on main.
        await MainActor.run {
            self.impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        }
        await setTask.value

        await asyncWaitUntil {
            let header = await self.capturedSessionManager?.authorizationHeader
            let token = await self.impl.getSharedSession()?.token
            return header == "Bearer web-jwt" || token == "web-jwt"
        }
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
