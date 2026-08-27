import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

// Verifies that in-memory event dedup runs unconditionally, that always-resend
// events (user interactions and product responses) are exempt from dedup, and cache-persistence stays gated on the
// cache being enabled + configured.
final class TestPlatformEventProcessorDedup: XCTestCase {

    private var sut: PlatformEventProcessor!
    private var impl: RoktInternalImplementation!
    private var originalImpl: RoktInternalImplementation!
    private var stub: MockTxnEventsHTTPClient!

    private let cacheFlagKey = "mobile-sdk-use-sdk-cache"
    private let mockedViewName = "dedup-test-view"
    private let mockedAttributes = ["email": "dedup@example.com"]

    override func setUp() {
        super.setUp()
        XCTestCase.prepareExperienceCacheTestFiles()
        XCTestCase.deleteExperienceCacheTestFiles()

        // Swap the shared implementation for a controlled instance with an injected txn HTTP stub so
        // we can observe exactly which events reach the wire. Cache is OFF by default on a fresh impl.
        originalImpl = Rokt.shared.roktImplementation
        stub = MockTxnEventsHTTPClient()
        impl = RoktInternalImplementation()
        impl.roktTagId = "tag-1"
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
        Rokt.shared.roktImplementation = impl

        sut = PlatformEventProcessor()
    }

    override func tearDown() {
        XCTestCase.deleteExperienceCacheTestFiles()
        Rokt.shared.roktImplementation = originalImpl
        sut = nil
        impl = nil
        stub = nil
        originalImpl = nil
        super.tearDown()
    }

    // MARK: - Helpers

    // Serialises the fixtures through RoktUXHelper's v2 sessions/events body — the exact wire
    // shape `onRoktPlatformEvent` now delivers.
    private func payload(_ events: [RoktEventRequest]) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(RoktSessionEventsBody(events: events)),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func settle(_ interval: TimeInterval = 0.3) {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
    }

    private func enableCache() {
        impl.initFeatureFlags = InitFeatureFlags(featureFlags: [cacheFlagKey: FeatureFlagItem(match: true)])
        impl.roktConfig = RoktConfig.Builder().cacheConfig(RoktConfig.CacheConfig()).build()
    }

    private func cacheProperties() -> LayoutPageCacheProperties {
        LayoutPageCacheProperties(
            viewName: mockedViewName,
            experienceCacheAttributes: mockedAttributes,
            pluginViewStates: nil,
            onPluginViewStateChange: nil
        )
    }

    private func productResponsePayload() -> [String: Any] {
        ["events": [[
            "event_type": "product_item_response",
            "instance_id": "00000000-0000-0000-0000-000000000001",
            "session_id": "session-1",
            "timestamp": 1_700_000_000_000,
            "data": [
                "parent_id": "response-option-1",
                "token": "test-response-token",
                "page_instance_guid": "page-1",
                "catalog_item_instance_guid": "catalog-item-1"
            ]
        ]]]
    }

    // MARK: - (a) Cache OFF: duplicate event is NOT re-sent

    func testCacheOffDuplicateEventIsNotResent() {
        sut.process(payload([.mock(eventType: .SignalImpression)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 1 }

        // Re-processing the exact same event must be deduped away even though the cache is off.
        sut.process(payload([.mock(eventType: .SignalImpression)]), executeId: "1", cacheProperties: nil)
        settle()

        XCTAssertEqual(stub.callCount, 1)
        XCTAssertEqual(impl.sentEventHashes.count, 1)
    }

    // MARK: - (b) Exempt (user-interaction) event IS re-sent even when duplicated

    func testCacheOffUserInteractionEventIsAlwaysResent() {
        sut.process(payload([.mock(eventType: .SignalUserInteraction)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 1 }

        // User interactions are exempt from dedup, so the duplicate must still reach the wire.
        sut.process(payload([.mock(eventType: .SignalUserInteraction)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 2 }

        XCTAssertEqual(stub.callCount, 2)
        // Exempt events are never recorded in the dedup set.
        XCTAssertEqual(impl.sentEventHashes.count, 0)
    }

    func testCacheOffActivationEventIsAlwaysResent() {
        sut.process(payload([.mock(eventType: .SignalActivation)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 1 }

        sut.process(payload([.mock(eventType: .SignalActivation)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 2 }

        XCTAssertEqual(stub.callCount, 2)
        XCTAssertEqual(impl.sentEventHashes.count, 0)
    }

    func testCacheOffProductResponseIsAlwaysResent() throws {
        sut.process(productResponsePayload(), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 1 }

        sut.process(productResponsePayload(), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 2 }

        XCTAssertEqual(stub.callCount, 2)
        XCTAssertEqual(impl.sentEventHashes.count, 0)
        for body in stub.capturedBodies {
            let events = try XCTUnwrap(body["events"] as? [[String: Any]])
            let event = try XCTUnwrap(events.first)
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(event["event_type"] as? String, "product_item_response")
            XCTAssertEqual(event["instance_id"] as? String, "00000000-0000-0000-0000-000000000001")
            let data = try XCTUnwrap(event["data"] as? [String: String])
            XCTAssertEqual(data["parent_id"], "response-option-1")
            XCTAssertEqual(data["token"], "test-response-token")
            XCTAssertEqual(data["catalog_item_instance_guid"], "catalog-item-1")
        }
    }

    func testCacheOnProductResponseIsAlwaysResent() {
        enableCache()
        sut.process(productResponsePayload(), executeId: "1", cacheProperties: cacheProperties())
        waitUntil { self.stub.callCount == 1 }

        sut.process(productResponsePayload(), executeId: "1", cacheProperties: cacheProperties())
        waitUntil { self.stub.callCount == 2 }

        XCTAssertEqual(stub.callCount, 2)
        XCTAssertEqual(impl.sentEventHashes.count, 0)
    }

    // MARK: - (c) Cache-persistence only runs when cache is enabled

    func testCacheOffDoesNotPersistSentEventHashes() {
        sut.process(payload([.mock(eventType: .SignalImpression)]),
                    executeId: "1",
                    cacheProperties: cacheProperties())
        settle(1)

        XCTAssertFalse(XCTestCase.experienceCacheExperiencesViewStateFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
    }

    func testCacheOnPersistsSentEventHashes() {
        enableCache()

        sut.process(payload([.mock(eventType: .SignalImpression)]),
                    executeId: "1",
                    cacheProperties: cacheProperties())
        waitUntil { self.stub.callCount == 1 }
        settle(1)

        XCTAssertTrue(XCTestCase.experienceCacheExperiencesViewStateFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
    }
}
