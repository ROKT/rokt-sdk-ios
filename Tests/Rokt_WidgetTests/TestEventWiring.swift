import XCTest
@testable import Rokt_Widget

final class TestEventWiring: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: MockEventsHTTPClient!

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = MockEventsHTTPClient()
    }

    override func tearDown() {
        impl = nil
        stub = nil
        super.tearDown()
    }

    private func injectService() {
        impl.makeEventServiceOverride = { [stub] tagId in
            EventService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                sessionManager: SessionTokenManager(),
                httpClient: stub!,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
    }

    private func sampleEvent() -> Event {
        Event(eventType: "impression", instanceId: "instance-1", timestamp: 1_700_000_000_000, data: ["k": "v"])
    }

    func test_v2Events_isEnabled() {
        XCTAssertTrue(impl.isV2EventsEnabled)
    }

    func test_dispatch_withTagId_sendsThroughService() {
        injectService()
        impl.roktTagId = "tag-1"

        impl.dispatchEvents([sampleEvent()])

        waitUntil { self.stub.callCount == 1 }
    }

    func test_dispatch_withoutTagId_doesNotSend() {
        injectService()

        impl.dispatchEvents([sampleEvent()])

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertEqual(stub.callCount, 0)
    }

    func test_dispatch_withEmptyEvents_doesNotSend() {
        injectService()
        impl.roktTagId = "tag-1"

        impl.dispatchEvents([])

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertEqual(stub.callCount, 0)
    }
}
