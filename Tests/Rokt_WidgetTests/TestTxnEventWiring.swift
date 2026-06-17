import XCTest
@testable import Rokt_Widget

final class TestTxnEventWiring: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: StubEventsHTTPClient!

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = StubEventsHTTPClient()
    }

    override func tearDown() {
        impl = nil
        stub = nil
        super.tearDown()
    }

    private func injectService() {
        impl.makeTxnEventServiceOverride = { [stub] tagId in
            TxnEventService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
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

    private func sampleEvent() -> TxnEvent {
        TxnEvent(eventType: "impression", instanceId: "instance-1", timestamp: 1_700_000_000_000, data: ["k": "v"])
    }

    func test_txnEvents_isEnabled() {
        XCTAssertTrue(impl.isTxnEventsEnabled)
    }

    func test_dispatch_withTagId_sendsThroughService() {
        injectService()
        impl.roktTagId = "tag-1"

        impl.dispatchTxnEvents([sampleEvent()])

        waitUntil { self.stub.callCount == 1 }
    }

    func test_dispatch_withoutTagId_doesNotSend() {
        injectService()

        impl.dispatchTxnEvents([sampleEvent()])

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertEqual(stub.callCount, 0)
    }

    func test_dispatch_withEmptyEvents_doesNotSend() {
        injectService()
        impl.roktTagId = "tag-1"

        impl.dispatchTxnEvents([])

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertEqual(stub.callCount, 0)
    }
}

private final class StubEventsHTTPClient: HTTPClientAdapter {
    private(set) var callCount = 0

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
        callCount += 1
        let url = URL(string: urlAddress) ?? URL(string: "https://apps.rokt.com")!
        let result = RoktHTTPRequestResult(
            httpURLResponse: HTTPURLResponse(url: url, statusCode: 202, httpVersion: nil, headerFields: nil),
            responseData: Data(#"{ "event_ids": ["event-1"] }"#.utf8),
            responseError: nil,
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
