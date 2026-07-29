import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

// Verifies that in-memory event dedup runs unconditionally, that always-resend
// events (user interactions) are exempt from dedup, and that cache-persistence stays gated on the
// cache being enabled + configured.
final class TestPlatformEventProcessorDedup: XCTestCase {

    private var sut: PlatformEventProcessor!
    private var impl: RoktInternalImplementation!
    private var originalImpl: RoktInternalImplementation!
    private var stub: MockTxnEventsHTTPClient!

    private let cacheFlagKey = "mobile-sdk-use-sdk-cache"
    private let mockedViewName = "dedup-test-view"
    private let mockedAttributes = ["email": "dedup1593754986316@rokt.com"]

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

    private func payload(_ events: [RoktEventRequest]) -> [String: Any] {
        let payload = RoktUXEventsPayload(events: events)
        guard let data = try? JSONEncoder().encode(payload),
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

    // MARK: - (a) Cache OFF: duplicate event is NOT re-sent

    func test_cacheOff_duplicateEvent_isNotResent() {
        sut.process(payload([.mock(eventType: .SignalImpression)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 1 }

        // Re-processing the exact same event must be deduped away even though the cache is off.
        sut.process(payload([.mock(eventType: .SignalImpression)]), executeId: "1", cacheProperties: nil)
        settle()

        XCTAssertEqual(stub.callCount, 1)
        XCTAssertEqual(impl.sentEventHashes.count, 1)
    }

    // MARK: - (b) Exempt (user-interaction) event IS re-sent even when duplicated

    func test_cacheOff_userInteractionEvent_isAlwaysResent() {
        sut.process(payload([.mock(eventType: .SignalUserInteraction)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 1 }

        // User interactions are exempt from dedup, so the duplicate must still reach the wire.
        sut.process(payload([.mock(eventType: .SignalUserInteraction)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 2 }

        XCTAssertEqual(stub.callCount, 2)
        // Exempt events are never recorded in the dedup set.
        XCTAssertEqual(impl.sentEventHashes.count, 0)
    }

    func test_cacheOff_activationEvent_isAlwaysResent() {
        sut.process(payload([.mock(eventType: .SignalActivation)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 1 }

        sut.process(payload([.mock(eventType: .SignalActivation)]), executeId: "1", cacheProperties: nil)
        waitUntil { self.stub.callCount == 2 }

        XCTAssertEqual(stub.callCount, 2)
        XCTAssertEqual(impl.sentEventHashes.count, 0)
    }

    // MARK: - (c) Cache-persistence only runs when cache is enabled

    func test_cacheOff_doesNotPersistSentEventHashes() {
        sut.process(payload([.mock(eventType: .SignalImpression)]),
                    executeId: "1",
                    cacheProperties: cacheProperties())
        settle(1)

        XCTAssertFalse(XCTestCase.experienceCacheExperiencesViewStateFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
    }

    func test_cacheOn_persistsSentEventHashes() {
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
