import XCTest
@testable import Rokt_Widget

final class TestTxnEventWiring: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: MockTxnEventsHTTPClient!

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = MockTxnEventsHTTPClient()
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
