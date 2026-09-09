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
        override func processLayoutPageExecutePayload(
            _ page: String,
            selectionId: String,
            viewName: String? = nil,
            attributes: [String: String]
        ) -> LayoutPageExecutePayload? {
            capturedPage = page
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
        RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: [echoedTrigger])

        settle(1)
        XCTAssertTrue(RealTimeEventManager.shared.getTriggeredEvents().isEmpty)
    }

    /// Control for the test above: in the live generation the echoed events are kept.
    func test_captureUntriggeredEvents_inCurrentGeneration_isKept() {
        impl.captureUntriggeredEvents([echoedEvent], generation: impl.currentSessionGeneration())
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
            experienceResponse: try String(decoding: renderFixture(), as: UTF8.self)
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

    // MARK: - Helpers

    private let echoedEvent = UntriggeredRealTimeEvent(
        triggerGuid: "parent-1", triggerEvent: "SignalResponse", eventType: "x", payload: "y"
    )

    private var echoedTrigger: RealTimeTrigger {
        RealTimeTrigger(
            parentGuid: "parent-1",
            eventTypeKey: "SignalResponse",
            eventTime: EventDateFormatter.getDateString(Date())
        )
    }

    /// Lets asynchronous work that follows an observed event run to completion.
    private func settle(_ interval: TimeInterval = 0.3) {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { settled.fulfill() }
        wait(for: [settled], timeout: 5)
    }
}
