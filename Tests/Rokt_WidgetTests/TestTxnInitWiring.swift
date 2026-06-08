import XCTest
@testable import Rokt_Widget

final class TestTxnInitWiring: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: StubInitHTTPClient!

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = StubInitHTTPClient()
    }

    override func tearDown() {
        impl = nil
        stub = nil
        super.tearDown()
    }

    private func injectService() {
        impl.makeTxnInitService = { [stub] tagId in
            TxnInitService(
                environment: .prod,
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
