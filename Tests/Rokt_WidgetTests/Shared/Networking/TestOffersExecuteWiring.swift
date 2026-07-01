import UIKit
import XCTest
@testable import Rokt_Widget

/// Drives `RoktInternalImplementation.execute(...)` through the v2 offers path so the
/// call-site wiring is exercised end to end: the offers service factory, the success
/// hand-off to the renderer, the failure handler, and the Mock-environment offline
/// transport. The offers stack itself is unit-tested in `TestOffersService` /
/// `TestSelectExperienceAdapter`; this covers the glue that joins it to `execute`.
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

    private var impl: CapturingImplementation!
    private var window: UIWindow!
    private var originalEnvironment: Environment!

    override func setUp() {
        super.setUp()
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

        // Wait for the background cache write to flush before reusing it.
        waitUntil({
            ExperienceCacheManager.getCachedExperienceResponse(
                viewName: viewName, attributes: attributes, cacheDuration: cacheDuration
            ) != nil
        }, timeout: 10)

        // Second execute serves the cached experience instead of fetching again.
        impl.capturedPage = nil
        impl.execute(viewName: viewName, attributes: attributes, config: cacheConfig)
        waitUntil({ self.impl.capturedPage != nil }, timeout: 10)
        XCTAssertTrue(try XCTUnwrap(impl.capturedPage).contains("render-session"))
    }
}
