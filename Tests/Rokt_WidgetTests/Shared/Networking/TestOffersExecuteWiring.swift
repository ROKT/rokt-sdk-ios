import UIKit
import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

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
        var capturedPayload: LayoutPageExecutePayload?
        /// Off for tests that only inspect the payload: a rendered placement keeps emitting events
        /// through the shared SDK instance after the test ends, into whichever test runs next.
        var rendersPlacements = true
        override func processLayoutPageExecutePayload(
            _ page: String,
            selectionId: String,
            viewName: String? = nil,
            attributes: [String: String],
            cacheGeneration: String? = nil
        ) -> LayoutPageExecutePayload? {
            capturedPage = page
            let payload = super.processLayoutPageExecutePayload(
                page, selectionId: selectionId, viewName: viewName, attributes: attributes,
                cacheGeneration: cacheGeneration
            )
            capturedPayload = payload
            return rendersPlacements ? payload : nil
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

    private var impl: CapturingImplementation!
    private var window: UIWindow!
    private var originalEnvironment: Environment!

    override func setUp() {
        super.setUp()
        RoktSDKDateHandler.customDate = nil
        originalEnvironment = config.environment
        Self.prepareExperienceCacheTestFiles()
        Self.deleteExperienceCacheTestFiles()
        impl = CapturingImplementation()
        // A real window/root so the success render hand-off has somewhere to attach.
        window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        RoktSDKDateHandler.customDate = nil
        Self.deleteExperienceCacheTestFiles()
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
        { tagId in
            OffersService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.2.2",
                layoutSchemaVersion: "2.8",
                sessionManager: TxnSessionManager(),
                httpClient: StubHTTPClient(data: data, status: status, error: error),
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

        // Wait for the asynchronous cache write to flush before reusing it. The write runs at background
        // quality of service and may be delayed on a busy host, so the wait is generous. It is not a
        // timing assertion.
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 60)
        XCTAssertNotNil(ExperienceCacheManager.getCachedExperienceResponse(
            viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
        ))

        // Second execute serves the cached experience instead of fetching again.
        impl.capturedPage = nil
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        XCTAssertTrue(try XCTUnwrap(impl.capturedPage).contains("render-session"))
    }

    /// A response fetched after the cached one expired is a new experience: the dismissal the
    /// customer gave the expired one must not stop the fresh one from rendering.
    func test_execute_cacheExpired_freshResponseStartsWithCleanPluginState() throws {
        let fixture = try executeAndDismissCachedPlacement()

        RoktSDKDateHandler.customDate = RoktSDKDateHandler.currentDate().addingTimeInterval(fixture.cacheDuration + 1)
        impl.capturedPayload = nil
        impl.execute(viewName: fixture.viewName, attributes: fixture.attributes, config: fixture.config)
        waitUntil({ self.impl.capturedPayload != nil }, timeout: 10)

        XCTAssertEqual(fixture.offersRequests(), 2, "an expired cache must go back to the network")
        XCTAssertNotEqual(impl.capturedPayload?.cacheProperties?.generation, fixture.generation)
        XCTAssertEqual(impl.capturedPayload?.cacheProperties?.pluginViewStates,
                       [RoktPluginViewState(pluginId: Self.renderPluginId)])
    }

    /// Within the TTL the cached experience is the same one the customer dismissed, so it stays dismissed.
    func test_execute_withinTTL_cacheHitRestoresDismissedState() throws {
        let fixture = try executeAndDismissCachedPlacement()

        impl.capturedPayload = nil
        impl.execute(viewName: fixture.viewName, attributes: fixture.attributes, config: fixture.config)
        waitUntil({ self.impl.capturedPayload != nil }, timeout: 10)

        XCTAssertEqual(fixture.offersRequests(), 1, "a valid cache must not go back to the network")
        XCTAssertEqual(impl.capturedPayload?.cacheProperties?.generation, fixture.generation)
        XCTAssertEqual(impl.capturedPayload?.cacheProperties?.pluginViewStates, [Self.dismissedState])
    }

    private static let renderPluginId = "render-plugin"
    private static let dismissedState = RoktPluginViewState(pluginId: renderPluginId,
                                                            offerIndex: 3,
                                                            isPluginDismissed: true)

    private struct CachedPlacementFixture {
        let viewName: String
        let attributes: [String: String]
        let cacheDuration: TimeInterval
        let config: RoktConfig
        let generation: String
        let offersRequests: () -> Int
    }

    /// Fetches and caches an experience, then records the customer dismissing its placement.
    private func executeAndDismissCachedPlacement() throws -> CachedPlacementFixture {
        initialize(cacheEnabled: true)
        impl.rendersPlacements = false
        let data = try renderFixture()
        var offersRequests = 0
        let makeOffersService = offersOverride(data: data, status: 200)
        impl.makeOffersServiceOverride = { tagId in
            offersRequests += 1
            return makeOffersService(tagId)
        }

        let viewName = "checkout"
        let attributes = ["email": "cache@rokt.com"]
        let cacheDuration = TimeInterval(30)
        let config = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: cacheDuration))
            .build()

        impl.execute(viewName: viewName, attributes: attributes, config: config)
        waitUntil({ self.impl.capturedPayload != nil }, timeout: 10)
        let cacheProperties = try XCTUnwrap(impl.capturedPayload?.cacheProperties)
        let cacheAttributes = cacheProperties.experienceCacheAttributes

        // The response and view state writes are asynchronous; wait for both to reach disk. The response
        // is written at background priority, which a busy host can delay by tens of seconds. The state
        // file is read unmapped: polling a mapped file while the writer replaces it faults.
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: cacheAttributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 60)
        cacheProperties.onPluginViewStateChange?(Self.dismissedState)
        let stateFileName = ExperienceCacheUtils.getPluginViewStateFileName(
            pluginId: Self.renderPluginId, viewName: viewName, attributes: cacheAttributes,
            generation: cacheProperties.generation
        )
        let stateFileUrl = try XCTUnwrap(ExperienceCacheManager.getFileUrl(name: stateFileName))
        waitUntil({
            guard let data = try? Data(contentsOf: stateFileUrl) else { return false }
            return ExperienceCacheUtils.getValidPluginViewState(pluginId: Self.renderPluginId, data: data)
                == Self.dismissedState
        }, timeout: 10)

        return CachedPlacementFixture(viewName: viewName,
                                      attributes: attributes,
                                      cacheDuration: cacheDuration,
                                      config: config,
                                      generation: cacheProperties.generation,
                                      offersRequests: { offersRequests })
    }
}
