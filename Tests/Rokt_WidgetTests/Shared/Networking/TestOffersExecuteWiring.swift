import UIKit
import XCTest
@testable import Rokt_Widget

/// Drives `RoktInternalImplementation.execute(...)` through the v2 offers path so the
/// call-site wiring is exercised end to end: the offers service factory, the success
/// hand-off to the renderer, the failure handler, and the Mock-environment offline
/// transport. The offers stack itself is unit-tested in `TestOffersService`;
/// this covers the glue that joins it to `execute`.
final class TestOffersExecuteWiring: XCTestCase {

    /// Captures the experience string handed to the renderer so the success path is
    /// observable without depending on the on-screen render completing.
    private final class CapturingImplementation: RoktInternalImplementation {
        var capturedPage: String?
        /// Runs inside the response commit, before the page is processed — a seam for racing it.
        var onCommit: (() -> Void)?
        override func processLayoutPageExecutePayload(
            _ page: String,
            selectionId: String,
            viewName: String? = nil,
            attributes: [String: String]
        ) -> LayoutPageExecutePayload? {
            capturedPage = page
            onCommit?()
            return super.processLayoutPageExecutePayload(
                page, selectionId: selectionId, viewName: viewName, attributes: attributes
            )
        }
    }

    /// One queued transport outcome: a body + status, or a transport-level error.
    private final class StubHTTPClient: HTTPClientAdapter {
        private let data: Data?
        private let status: Int
        private let error: Error?
        init(data: Data?, status: Int, error: Error? = nil) {
            self.data = data
            self.status = status
            self.error = error
        }

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
            let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
            let result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil),
                responseData: data,
                responseError: error,
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

    /// Holds the transport completion until `release()`, so a `clearSession()` can land while
    /// the offers call is still in flight.
    private final class DeferredHTTPClient: HTTPClientAdapter {
        private let data: Data?
        private let status: Int
        private let lock = NSLock()
        private var pending: (() -> Void)?
        private var requests = 0
        init(data: Data?, status: Int) {
            self.data = data
            self.status = status
        }

        var requestCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return requests
        }

        func release() {
            lock.lock()
            let completion = pending
            pending = nil
            lock.unlock()
            completion?()
        }

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
            let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
            let result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil),
                responseData: data,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
            lock.lock()
            defer { lock.unlock() }
            requests += 1
            pending = { completionQueue.async { completionHandler?(result) } }
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

    /// Scratch store so `clearSession()` never touches `UserDefaults.standard`.
    private final class InMemoryTxnStore: TxnSessionStore {
        private var values: [String: String] = [:]
        func string(forKey key: String) -> String? { values[key] }
        func setString(_ value: String, forKey key: String) { values[key] = value }
        func removeValue(forKey key: String) { values[key] = nil }
    }

    private var impl: CapturingImplementation!
    private var window: UIWindow!
    private var originalEnvironment: Environment!

    override func setUp() {
        super.setUp()
        originalEnvironment = config.environment
        Self.prepareExperienceCacheTestFiles()
        Self.deleteExperienceCacheTestFiles()
        ensureDocumentDirectoryExists()
        RealTimeEventManager.shared.clearAllEvents()
        // The clear is queued, not waited for; this read orders the test thread behind it before the next step.
        _ = RealTimeEventManager.shared.getTriggeredEvents()
        RoktLogger.shared.sessionId = nil
        impl = CapturingImplementation()
        // A real window/root so the success render hand-off has somewhere to attach.
        window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        Self.deleteExperienceCacheTestFiles()
        RealTimeEventManager.shared.clearAllEvents()
        // The clear is queued, not waited for; this read orders the test thread behind it before the next step.
        _ = RealTimeEventManager.shared.getTriggeredEvents()
        RoktLogger.shared.sessionId = nil
        config.environment = originalEnvironment
        window?.isHidden = true
        window = nil
        impl = nil
        super.tearDown()
    }

    /// Brings the SDK to `isInitialized` with a stubbed init response.
    private func initialize(cacheEnabled: Bool = false) {
        impl.makeTxnInitServiceOverride = { tagId in
            let stub = StubHTTPClient(data: Data(
                """
                {
                  "session_id": "sess-1",
                  "session_token": { "token": "jwt", "expires_at": 32503680000000 },
                  "feature_flags": { "rokt-tracking-status": true, "mobile-sdk-use-sdk-cache": \(cacheEnabled) },
                  "fonts": []
                }
                """.utf8
            ), status: 200)
            return TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                layoutSchemaVersion: "1.0",
                httpClient: stub,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)
        waitUntil({ self.impl.isInitialized }, timeout: 10)
    }

    private func offersOverride(data: Data?, status: Int, error: Error? = nil) -> (String) -> OffersService {
        offersOverride(httpClient: StubHTTPClient(data: data, status: status, error: error))
    }

    private func offersOverride(httpClient: HTTPClientAdapter) -> (String) -> OffersService {
        { tagId in
            OffersService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                layoutSchemaVersion: "2.8",
                sessionManager: TxnSessionManager(),
                httpClient: httpClient,
                maxRetries: 0,
                sleep: { _ in }
            )
        }
    }

    private func renderFixture() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "offers_render", withExtension: "json"),
            "offers_render.json missing from the test bundle"
        )
        return try Data(contentsOf: url)
    }

    func test_execute_v2Offers_success_handsRenderablePageToRenderer() throws {
        initialize()
        impl.makeOffersServiceOverride = offersOverride(data: try renderFixture(), status: 200)

        // `pageinit` is a 13-digit epoch-ms in the past, so the timing parity block records it.
        impl.execute(viewName: "checkout", attributes: ["email": "a@b.com", "pageinit": "1700000000000"], config: nil)

        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        let page = try XCTUnwrap(impl.capturedPage)
        XCTAssertTrue(page.contains("render-session"), "renderer should receive the adapted offers experience")
    }

    func test_execute_v2Offers_failure_emitsPlacementFailure() {
        initialize()
        impl.makeOffersServiceOverride = offersOverride(data: nil, status: 500)

        let failed = expectation(description: "placement failure surfaced")
        impl.execute(viewName: "checkout", attributes: [:], config: nil) { event in
            if event is RoktEvent.PlacementFailure { failed.fulfill() }
        }

        wait(for: [failed], timeout: 5)
    }

    func test_execute_v2Offers_mockEnvironment_usesOfflineOffersTransport() {
        config.environment = .Mock
        initialize()
        // No offers override: defaultOffersService builds the Mock offline transport.

        impl.execute(viewName: "checkout", attributes: [:], config: nil)

        // The offline transport still decodes + adapts, so the success hand-off runs.
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        XCTAssertNotNil(impl.capturedPage)
    }

    func test_execute_v2Offers_cacheEnabled_writesThenReusesCachedExperience() throws {
        initialize(cacheEnabled: true)
        impl.makeOffersServiceOverride = offersOverride(data: try renderFixture(), status: 200)

        let viewName = "checkout"
        let attributes = ["email": "cache@rokt.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()

        // First execute fetches offers and writes the experience to the cache.
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        XCTAssertNotNil(impl.capturedPage)

        // Wait for the background cache write to flush before reusing it.
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)
        XCTAssertNotNil(ExperienceCacheManager.getCachedExperienceResponse(
            viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
        ))

        // Second execute serves the cached experience instead of fetching again.
        impl.capturedPage = nil
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        XCTAssertTrue(try XCTUnwrap(impl.capturedPage).contains("render-session"))
    }

    // MARK: - clearSession() while a placement is in flight

    /// A placement whose offers call completes after `clearSession()` belongs to the session that
    /// was cleared: it is not shown, does not restore the legacy session id, does not write the
    /// cache — and `execute` is free again for the next placement.
    func test_execute_clearSessionWhileOffersInFlight_discardsTheLateResult() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "late@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        let client = DeferredHTTPClient(data: try renderFixture(), status: 200)
        impl.makeOffersServiceOverride = offersOverride(httpClient: client)

        let discarded = expectation(description: "the late placement reports failure")
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            if event is RoktEvent.PlacementFailure { discarded.fulfill() }
        }
        waitUntil({ client.requestCount == 1 }, timeout: 10)
        impl.clearSession()
        client.release()
        wait(for: [discarded], timeout: 10)
        settle()

        XCTAssertNil(impl.capturedPage, "a placement that completes after clearSession is not rendered")
        XCTAssertNil(impl.getSessionId(), "the cleared session id must not come back")
        XCTAssertNil(RoktLogger.shared.sessionId)
        let cached = ExperienceCacheManager.getCachedExperienceResponse(
            viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
        )
        XCTAssertNil(cached, "an experience fetched in the cleared session is not cached for the next one")

        // The fence released `isExecuting`: the next placement is accepted and renders.
        impl.makeOffersServiceOverride = offersOverride(data: try renderFixture(), status: 200)
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
    }

    /// The offers response echoes events for the next placement to forward. Captured after a
    /// `clearSession()`, they would seed the new session's real-time event store with the old one's.
    func test_captureUntriggeredEvents_afterClearSession_isDropped() {
        impl.txnSessionStore = InMemoryTxnStore()
        let generation = impl.currentSessionGeneration()
        impl.clearSession()

        impl.captureUntriggeredEvents([echoedEvent], generation: generation)

        assertEchoedEventWasDropped()
    }

    /// Control for the test above: in the live generation the echoed events are kept.
    func test_captureUntriggeredEvents_inCurrentGeneration_isKept() {
        impl.captureUntriggeredEvents([echoedEvent], generation: impl.currentSessionGeneration())
        RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: [echoedTrigger])

        waitUntil({ RealTimeEventManager.shared.getTriggeredEvents().count == 1 }, timeout: 5)
    }

    /// The factory `execute` uses when no override is installed must hand the response's echoed
    /// events to the fence with the generation the placement started in, not straight to the store.
    func test_defaultOffersService_dropsEchoedEventsCapturedAfterClearSession() {
        impl.txnSessionStore = InMemoryTxnStore()
        let service = impl.defaultOffersService(roktTagId: "tag-1", generation: impl.currentSessionGeneration())
        impl.clearSession()

        service.captureEvents([echoedEvent])

        assertEchoedEventWasDropped()
    }

    /// Control for the test above: used in the generation it was built in, the factory's service
    /// still delivers echoed events to the store.
    func test_defaultOffersService_keepsEchoedEventsCapturedInTheLiveGeneration() {
        impl.txnSessionStore = InMemoryTxnStore()
        let service = impl.defaultOffersService(roktTagId: "tag-1", generation: impl.currentSessionGeneration())

        service.captureEvents([echoedEvent])
        RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: [echoedTrigger])

        waitUntil({ RealTimeEventManager.shared.getTriggeredEvents().count == 1 }, timeout: 5)
    }

    /// After `clearSession()` every placement bypasses the cache until one of them has fetched a
    /// fresh experience: a failed placement must not hand the next one whatever is still on disk.
    func test_clearSession_keepsBypassingTheCacheUntilAFreshExperienceIsFetched() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "stale@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        impl.clearSession()
        // Whatever is still on disk after the reset must not be served.
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: viewName,
            attributes: attributes,
            experienceResponse: try XCTUnwrap(String(bytes: renderFixture(), encoding: .utf8))
        )
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)
        impl.makeOffersServiceOverride = offersOverride(data: nil, status: 500)

        let firstFailure = expectation(description: "the first placement after the reset fails")
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            if event is RoktEvent.PlacementFailure { firstFailure.fulfill() }
        }
        wait(for: [firstFailure], timeout: 10)

        let secondFailure = expectation(description: "the second placement still bypasses the cache")
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            if event is RoktEvent.PlacementFailure { secondFailure.fulfill() }
        }
        wait(for: [secondFailure], timeout: 10)
        XCTAssertNil(impl.capturedPage)
    }

    /// A placement served from the cache is fenced like one served from the network: a `clearSession()` that
    /// lands after the cache read and before the commit means the cached experience is not shown, does not
    /// restore the legacy session id it carries and does not re-seed the real-time event store the clear emptied.
    func test_execute_clearSessionAfterTheCacheRead_discardsTheCachedPlacement() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "cached@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: viewName, attributes: attributes, experienceResponse: try renderFixtureWithEchoedEvent()
        )
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)
        // The placement must be served from the cache; a fetch here would be the wrong path and fails locally.
        impl.makeOffersServiceOverride = offersOverride(data: nil, status: 500)

        var clearedAfterTheCacheRead = false
        impl.unitTest_beforeCacheHitCommit = { [weak impl] in
            impl?.clearSession()
            clearedAfterTheCacheRead = true
        }
        let discarded = expectation(description: "the cached placement reports failure")
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            if event is RoktEvent.PlacementFailure { discarded.fulfill() }
        }
        wait(for: [discarded], timeout: 10)
        settle()

        XCTAssertTrue(clearedAfterTheCacheRead, "the placement was served from the cache")
        XCTAssertNil(impl.capturedPage, "a cached placement that resolves after clearSession is not rendered")
        XCTAssertNil(impl.getSessionId(), "the session id the cached experience carries must not come back")
        XCTAssertNil(RoktLogger.shared.sessionId)
        assertEchoedEventWasDropped()
    }

    // MARK: - Helpers

    private let echoedEvent = UntriggeredRealTimeEvent(
        triggerGuid: "parent-1", triggerEvent: "SignalResponse", eventType: "x", payload: "y"
    )

    /// The positive control for the test above: served from the cache with no `clearSession()`, the cached
    /// experience is rendered and the echoed event it carries reaches the real-time event store. It proves the
    /// cache path decodes the fixture the fence test then drops.
    func test_execute_cachedExperienceWithEchoedEvent_isRenderedAndItsEventReachesTheStore() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "cached-control@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: viewName, attributes: attributes, experienceResponse: try renderFixtureWithEchoedEvent()
        )
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)
        // The placement must be served from the cache; a fetch here would be the wrong path and fails locally.
        impl.makeOffersServiceOverride = offersOverride(data: nil, status: 500)

        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        settle()

        XCTAssertNotNil(impl.capturedPage, "a cached placement with no clearSession is rendered")
        assertEchoedEventWasKept()
    }

    /// The render fixture carrying `echoedEvent` for the next placement, so an experience served from the
    /// cache has something to hand the real-time event store.
    private func renderFixtureWithEchoedEvent() throws -> String {
        let fixture = try XCTUnwrap(String(bytes: renderFixture(), encoding: .utf8))
        let opening = try XCTUnwrap(fixture.firstIndex(of: "{"))
        let echoed = """
        "eventData": { "parent-1": { "events": { "SignalResponse": { "eventType": "x", "payload": "y" } } } },
        """
        return String(fixture[...opening]) + echoed + String(fixture[fixture.index(after: opening)...])
    }

    private var echoedTrigger: RealTimeTrigger {
        RealTimeTrigger(
            parentGuid: "parent-1",
            eventTypeKey: "SignalResponse",
            eventTime: EventDateFormatter.getDateString(Date())
        )
    }

    private let controlEvent = UntriggeredRealTimeEvent(
        triggerGuid: "control-1", triggerEvent: "SignalResponse", eventType: "x", payload: "y"
    )

    private var controlTrigger: RealTimeTrigger {
        RealTimeTrigger(
            parentGuid: "control-1",
            eventTypeKey: "SignalResponse",
            eventTime: EventDateFormatter.getDateString(Date())
        )
    }

    /// Anchors "the echoed event was dropped" on a positive read: a control event is stored
    /// directly and both triggers are marked in one batch, so once the control shows up as
    /// triggered the same pass would have surfaced the echoed event had it reached the store.
    /// The positive twin of `assertEchoedEventWasDropped`: the same batch marks both triggers, and both surface.
    private func assertEchoedEventWasKept() {
        RealTimeEventManager.shared.addUntriggeredEvents([controlEvent])
        RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: [echoedTrigger, controlTrigger])

        waitUntil({ RealTimeEventManager.shared.getTriggeredEvents().count == 2 }, timeout: 5)
        XCTAssertEqual(
            Set(RealTimeEventManager.shared.getTriggeredEvents().map(\.parentGuid)), ["parent-1", "control-1"]
        )
    }

    private func assertEchoedEventWasDropped() {
        RealTimeEventManager.shared.addUntriggeredEvents([controlEvent])
        RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: [echoedTrigger, controlTrigger])

        waitUntil({ !RealTimeEventManager.shared.getTriggeredEvents().isEmpty }, timeout: 5)
        XCTAssertEqual(RealTimeEventManager.shared.getTriggeredEvents().map(\.parentGuid), ["control-1"])
    }

    /// A `clearSession()` that arrives while the response is being committed waits for the commit and then
    /// wins: the placement is not rendered, the session id the commit restored is gone, nothing stays cached.
    func test_execute_clearSessionDuringTheResponseCommit_waitsForItThenWins() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "commit@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        impl.makeOffersServiceOverride = offersOverride(data: try renderFixture(), status: 200)

        let clearSessionReturned = expectation(description: "clearSession returned")
        var clearSessionReturnedDuringCommit = true
        impl.onCommit = { [weak impl] in
            // clearSession from another queue while the commit holds the fence: it has to wait.
            let entered = DispatchSemaphore(value: 0)
            let returned = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                entered.signal()
                impl?.clearSession()
                returned.signal()
                clearSessionReturned.fulfill()
            }
            entered.wait()
            clearSessionReturnedDuringCommit = returned.wait(timeout: .now() + 0.3) == .success
        }
        let discarded = expectation(description: "the late placement reports failure")
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            if event is RoktEvent.PlacementFailure { discarded.fulfill() }
        }
        wait(for: [clearSessionReturned, discarded], timeout: 10)
        settle()
        settle()

        XCTAssertFalse(clearSessionReturnedDuringCommit, "clearSession waits for a commit in progress")
        XCTAssertNotNil(impl.capturedPage, "a commit that started before clearSession runs to its end")
        XCTAssertNil(impl.getSessionId(), "the session id the commit restored does not survive the clear")
        XCTAssertNil(RoktLogger.shared.sessionId)
        let cached = ExperienceCacheManager.getCachedExperienceResponse(
            viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
        )
        XCTAssertNil(cached, "the experience committed just before the clear is not cached for the next session")
    }

    /// The cache-hit sibling of the test above. A `clearSession()` that arrives while a cached experience is being
    /// committed waits for the commit and then wins: the cached placement is not shown, the session id it restored
    /// is gone and the cached experience goes with the session it was fetched in.
    func test_execute_clearSessionDuringTheCachedCommit_waitsForItThenWins() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "cached-commit@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: viewName,
            attributes: attributes,
            experienceResponse: try XCTUnwrap(String(bytes: renderFixture(), encoding: .utf8))
        )
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)
        // The placement must be served from the cache; a fetch here would be the wrong path and fails locally.
        impl.makeOffersServiceOverride = offersOverride(data: nil, status: 500)

        let clearSessionReturned = expectation(description: "clearSession returned")
        let clearSessionLanded = DispatchSemaphore(value: 0)
        var clearSessionReturnedDuringCommit = true
        impl.onCommit = { [weak impl] in
            // clearSession from another queue while the cached commit holds the fence: it has to wait.
            let entered = DispatchSemaphore(value: 0)
            let returned = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                entered.signal()
                impl?.clearSession()
                returned.signal()
                clearSessionLanded.signal()
                clearSessionReturned.fulfill()
            }
            entered.wait()
            clearSessionReturnedDuringCommit = returned.wait(timeout: .now() + 0.3) == .success
        }
        // Once the commit has released the fence, let that clearSession land before the render is re-checked, so
        // the re-check is exercised on every run and not only when the other queue takes the lock first.
        impl.unitTest_afterCacheHitCommit = { _ = clearSessionLanded.wait(timeout: .now() + 5) }
        let discarded = expectation(description: "the cached placement reports failure")
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            if event is RoktEvent.PlacementFailure { discarded.fulfill() }
        }
        wait(for: [clearSessionReturned, discarded], timeout: 10)
        settle()
        settle()

        XCTAssertFalse(clearSessionReturnedDuringCommit, "clearSession waits for a cached commit in progress")
        XCTAssertNotNil(impl.capturedPage, "a cached commit that started before clearSession runs to its end")
        XCTAssertNil(impl.getSessionId(), "the session id the cached experience restored does not survive the clear")
        XCTAssertNil(RoktLogger.shared.sessionId)
        let cached = ExperienceCacheManager.getCachedExperienceResponse(
            viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
        )
        XCTAssertNil(cached, "the cached experience goes with the session it was fetched in")
    }

    /// The generation a placement is checked against and whether it may read the cache are one reading under the
    /// generation lock: a `clearSession()` on another queue waits for that reading to finish, so it can never hand a
    /// placement the new generation while leaving the departing customer's cached experience readable. Once the
    /// clear lands, the placement is discarded whichever way it resolves — from the cache or from the network.
    func test_execute_clearSessionDuringThePlacementStart_waitsForItThenDiscardsThePlacement() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "start@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        // The departing customer's experience is on disk and would be served were the bypass not read with the
        // generation; a fetch, should the placement reach the network instead, fails locally.
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: viewName,
            attributes: attributes,
            experienceResponse: try XCTUnwrap(String(bytes: renderFixture(), encoding: .utf8))
        )
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)
        impl.makeOffersServiceOverride = offersOverride(data: nil, status: 500)

        let clearSessionReturned = expectation(description: "clearSession returned")
        let clearSessionLanded = DispatchSemaphore(value: 0)
        var clearSessionReturnedDuringStart = true
        impl.unitTest_duringPlacementStart = { [weak impl] in
            // clearSession from another queue while the placement's start holds the lock: it has to wait.
            let entered = DispatchSemaphore(value: 0)
            let returned = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                entered.signal()
                impl?.clearSession()
                returned.signal()
                clearSessionLanded.signal()
                clearSessionReturned.fulfill()
            }
            entered.wait()
            clearSessionReturnedDuringStart = returned.wait(timeout: .now() + 0.3) == .success
        }
        // Should the cached experience still be on disk when it is read, let the clear land before the commit is
        // attempted, so the fence is exercised on every run and not only when the other queue takes the lock first.
        impl.unitTest_beforeCacheHitCommit = { _ = clearSessionLanded.wait(timeout: .now() + 5) }
        let discarded = expectation(description: "the placement reports failure")
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            if event is RoktEvent.PlacementFailure { discarded.fulfill() }
        }
        wait(for: [clearSessionReturned, discarded], timeout: 10)
        settle()

        XCTAssertFalse(clearSessionReturnedDuringStart, "clearSession waits for a placement's start to be read")
        XCTAssertNil(impl.capturedPage, "the departing customer's cached experience is not shown to the next one")
        XCTAssertNil(impl.getSessionId(), "the cleared session id must not come back")
    }

    /// A `clearSession()` that lands after a placement has started but before its offers request is built belongs to
    /// the customer leaving: the request is not sent, and the session the server would mint for it is never written
    /// to the store the next customer's placement restores from.
    func test_execute_clearSessionBeforeTheOffersRequestIsBuilt_sendsNothingAndPersistsNoSession() throws {
        let store = InMemoryTxnStore()
        impl.txnSessionStore = store
        initialize()
        let client = DeferredHTTPClient(data: try renderFixture(), status: 200)
        // A store-backed session manager, built with the request as in production, so a session the response
        // carries would be persisted where the next placement restores from.
        impl.makeOffersServiceOverride = { tagId in
            OffersService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                layoutSchemaVersion: "2.8",
                sessionManager: TxnSessionManager(roktTagId: tagId, store: store),
                httpClient: client,
                maxRetries: 0,
                sleep: { _ in }
            )
        }
        let generationBefore = impl.currentSessionGeneration()
        let clearSessionReturned = expectation(description: "clearSession returned")
        let clearSessionLanded = DispatchSemaphore(value: 0)
        impl.unitTest_duringPlacementStart = { [weak impl] in
            // clearSession from another queue once the placement's start has been read.
            DispatchQueue.global().async {
                impl?.clearSession()
                clearSessionLanded.signal()
                clearSessionReturned.fulfill()
            }
        }
        // Let the clear land before the request is built, so the window is exercised on every run.
        impl.unitTest_beforeOffersServiceBuilt = { _ = clearSessionLanded.wait(timeout: .now() + 5) }
        let discarded = expectation(description: "the placement reports failure")
        impl.execute(viewName: "checkout", attributes: ["email": "leaving@example.com"], config: nil) { event in
            if event is RoktEvent.PlacementFailure { discarded.fulfill() }
        }
        wait(for: [clearSessionReturned], timeout: 10)
        // Were a request sent regardless, let it reach the transport and be answered, so whatever its response
        // persisted is visible below.
        settle()
        client.release()
        wait(for: [discarded], timeout: 10)
        settle()

        XCTAssertEqual(impl.currentSessionGeneration(), generationBefore + 1, "the clear landed")
        XCTAssertEqual(client.requestCount, 0, "the departing customer's attributes are not sent to start a new session")
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.sessionId), "no session is left for the next customer")
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.token))
        XCTAssertNil(impl.capturedPage)

        // The fence released `isExecuting`: the next placement is accepted and renders.
        impl.unitTest_duringPlacementStart = nil
        impl.unitTest_beforeOffersServiceBuilt = nil
        impl.makeOffersServiceOverride = offersOverride(data: try renderFixture(), status: 200)
        impl.execute(viewName: "checkout", attributes: ["email": "arriving@example.com"], config: nil)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
    }

    /// The offers service is built while the placement's session is still current, but the request is sent on its
    /// own task afterwards. A `clearSession()` that lands in that gap belongs to the customer leaving: neither their
    /// attributes nor the token the service restored are sent, no session is written for the next customer, the
    /// placement reports failure to its caller, and `execute` is free again.
    func test_execute_clearSessionAfterTheOffersServiceIsBuilt_sendsNothingAndPersistsNoSession() throws {
        let store = InMemoryTxnStore()
        impl.txnSessionStore = store
        initialize()
        let client = DeferredHTTPClient(data: try renderFixture(), status: 200)
        let clearSessionReturned = expectation(description: "clearSession returned")
        // A store-backed session manager, built with the request as in production, so a session the response
        // carries would be persisted where the next placement restores from. The session is cleared on the sending
        // task, after the service was built and just before it checks whether it may still send.
        impl.makeOffersServiceOverride = { [weak impl] tagId in
            var service = OffersService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                layoutSchemaVersion: "2.8",
                sessionManager: TxnSessionManager(roktTagId: tagId, store: store),
                httpClient: client,
                maxRetries: 0,
                sleep: { _ in }
            )
            service.unitTest_beforeSend = {
                impl?.clearSession()
                clearSessionReturned.fulfill()
            }
            return service
        }
        let generationBefore = impl.currentSessionGeneration()
        var events: [RoktEvent] = []
        let discarded = expectation(description: "the placement reports failure")
        impl.execute(viewName: "checkout", attributes: ["email": "leaving@example.com"], config: nil) { event in
            events.append(event)
            if event is RoktEvent.PlacementFailure { discarded.fulfill() }
        }
        wait(for: [clearSessionReturned], timeout: 10)
        // Were a request sent regardless, let it reach the transport and be answered, so whatever its response
        // persisted is visible below.
        settle()
        client.release()
        wait(for: [discarded], timeout: 10)
        settle()

        XCTAssertEqual(impl.currentSessionGeneration(), generationBefore + 1, "the clear landed")
        XCTAssertEqual(client.requestCount, 0, "neither the departing customer's attributes nor their token are sent")
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.sessionId), "no session is left for the next customer")
        XCTAssertNil(store.string(forKey: TxnSessionStoreKeys.token))
        XCTAssertTrue(events.contains(where: { $0 is RoktEvent.HideLoadingIndicator }), "the loading indicator is dismissed")
        XCTAssertTrue(events.contains(where: { $0 is RoktEvent.PlacementFailure }), "the failure reaches the caller")
        XCTAssertNil(impl.capturedPage)
        XCTAssertNil(impl.getSessionId(), "the cleared session id must not come back")

        // The fence released `isExecuting`: the next placement is accepted and renders.
        impl.makeOffersServiceOverride = offersOverride(data: try renderFixture(), status: 200)
        impl.execute(viewName: "checkout", attributes: ["email": "arriving@example.com"], config: nil)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
    }

    /// A placement releases `isExecuting` before its result is checked against the session fence, so a second
    /// placement can start inside that window — after a `clearSession()` — and take over the shared event handler
    /// and embedded views. The first placement's discarded result must then fail to the caller that started it, not
    /// to the second placement's caller, and must leave the second placement's handler in place so it renders.
    func test_execute_placementDiscardedAfterClearSession_failsToItsOwnCallerAndLeavesTheNextPlacementIntact() throws {
        impl.txnSessionStore = InMemoryTxnStore()
        initialize(cacheEnabled: true)
        let viewName = "checkout"
        let attributes = ["email": "handover@example.com"]
        let cacheDuration = TimeInterval(300)
        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: viewName,
            attributes: attributes,
            experienceResponse: try XCTUnwrap(String(bytes: renderFixture(), encoding: .utf8))
        )
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)
        // The first placement is served from the cache. The second fetches (the clear bypasses the cache) and its
        // response is held, so the first placement's discarded result is dealt with while the second is in flight.
        let client = DeferredHTTPClient(data: try renderFixture(), status: 200)
        impl.makeOffersServiceOverride = offersOverride(httpClient: client)

        var firstEvents: [RoktEvent] = []
        var secondEvents: [RoktEvent] = []
        var secondResponseReleased = false
        var secondHidLoadingAfterItsResponse = false
        var secondStarted = false
        impl.unitTest_afterCacheHitCommit = { [weak impl] in
            // The first placement has released `isExecuting` and committed its cached experience, and has not yet
            // re-checked the fence. Clear the session and start the second placement inside that window.
            guard !secondStarted, let impl else { return }
            secondStarted = true
            impl.clearSession()
            impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
                secondEvents.append(event)
                if event is RoktEvent.HideLoadingIndicator, secondResponseReleased {
                    secondHidLoadingAfterItsResponse = true
                }
            }
        }
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig) { event in
            firstEvents.append(event)
        }
        // The cached path runs synchronously: by here the first placement's result has been discarded.
        XCTAssertTrue(secondStarted, "the second placement started inside the first placement's fence window")
        XCTAssertTrue(firstEvents.contains(where: { $0 is RoktEvent.PlacementFailure }),
                      "the discarded placement reports its failure to the caller that started it")
        XCTAssertFalse(secondEvents.contains(where: { $0 is RoktEvent.PlacementFailure }),
                       "the second placement's caller never hears the first placement's failure")
        waitUntil({ client.requestCount == 1 }, timeout: 10)

        impl.capturedPage = nil
        secondResponseReleased = true
        client.release()
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        settle()

        XCTAssertNotNil(impl.capturedPage, "the second placement renders")
        XCTAssertTrue(secondHidLoadingAfterItsResponse,
                      "the second placement's render dismisses its own loading indicator, so its handler survived")
    }

    /// Lets asynchronous work that follows an observed event run to completion.
    private func settle() {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 5)
    }
}
