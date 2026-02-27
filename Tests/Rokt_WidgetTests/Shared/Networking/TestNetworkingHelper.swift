import XCTest
@testable import Rokt_Widget
import Mocker

class TestNetworkingHelper: XCTestCase {

    private static let BE_HEADER_PAGE_IDENTIFIER_KEY = "rokt-page-identifier"

    func test_updateMParticleKitDetails() {
        let mParticleKitDetails = MParticleKitDetails(sdkVersion: "1.2.3", kitVersion: "4.5.6")
        NetworkingHelper.updateMParticleKitDetails(mParticleKitDetails: mParticleKitDetails)

        XCTAssertEqual(NetworkingHelper.shared.mParticleKitDetails?.sdkVersion, "1.2.3")
        XCTAssertEqual(NetworkingHelper.shared.mParticleKitDetails?.kitVersion, "4.5.6")
    }

    func test_getCommonHeaders() {
        let headers = NetworkingHelper.getCommonHeaders([:])

        XCTAssertNotNil(headers[RoktHeaderKeys.sdkVersion])
    }

    func test_getCommonHeaders_withMParticleKitDetails() {
        let mParticleKitDetails = MParticleKitDetails(sdkVersion: "1.2.3", kitVersion: "4.5.6")
        NetworkingHelper.updateMParticleKitDetails(mParticleKitDetails: mParticleKitDetails)

        let headers = NetworkingHelper.getCommonHeaders([:])

        XCTAssertEqual(headers[RoktHeaderKeys.mParticleSdkVersion], "1.2.3")
        XCTAssertEqual(headers[RoktHeaderKeys.mParticleKitVersion], "4.5.6")
    }

    func test_isRetryableStatusCode() {
        // Retryable codes
        XCTAssertTrue(NetworkingHelper.isRetryableStatusCode(500)) // Internal Server Error
        XCTAssertTrue(NetworkingHelper.isRetryableStatusCode(502)) // Bad Gateway
        XCTAssertTrue(NetworkingHelper.isRetryableStatusCode(503)) // Service Unavailable

        // Non-retryable codes
        XCTAssertFalse(NetworkingHelper.isRetryableStatusCode(200)) // OK
        XCTAssertFalse(NetworkingHelper.isRetryableStatusCode(400)) // Bad Request
        XCTAssertFalse(NetworkingHelper.isRetryableStatusCode(404)) // Not Found
        XCTAssertFalse(NetworkingHelper.isRetryableStatusCode(nil)) // Nil input
        XCTAssertFalse(NetworkingHelper.isRetryableStatusCode(999)) // Unhandled code
    }

    func test_common_header_defaults() throws {
        let headers = NetworkingHelper.getCommonHeaders([:])

        XCTAssertNotNil(headers[RoktHeaderKeys.osType])
        XCTAssertNotNil(headers[RoktHeaderKeys.uiLocale])
        XCTAssertNotNil(headers[RoktHeaderKeys.osVersion])
        XCTAssertNotNil(headers[RoktHeaderKeys.deviceModel])
        XCTAssertNotNil(headers[RoktHeaderKeys.packageName])

        // Also check standard headers are present
        XCTAssertNotNil(headers[HTTPHeader.contentType])
        XCTAssertNotNil(headers[HTTPHeader.accept])
    }

    func test_pageIdentifier_included_in_network_request() {
        let expectation = self.expectation(description: "Network request with pageIdentifier")
        var capturedRequest: URLRequest?

        let experienceURL = URL(string: "https://mobile-api.rokt.com/v1/experiences")!
        var mock = Mock(url: experienceURL, dataType: .json, statusCode: 200, data: [
            .post: Data("{\"placements\":[]}".utf8)
        ])
        mock.onRequest = { request, _ in
            capturedRequest = request
            expectation.fulfill()
        }
        mock.register()

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        RoktNetWorkAPI.getExperienceData(
            params: ["test": "value"],
            roktTagId: "test-tag-id",
            trackingConsent: nil,
            pageIdentifier: "test-page",
            onRequestStart: nil,
            successLayout: nil,
            failure: nil
        )

        waitForExpectations(timeout: 2.0, handler: nil)

        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.allHTTPHeaderFields?[Self.BE_HEADER_PAGE_IDENTIFIER_KEY], "test-page")
    }

    func test_pageIdentifier_not_included_when_nil() {
        let expectation = self.expectation(description: "Network request without pageIdentifier")
        var capturedRequest: URLRequest?

        let experienceURL = URL(string: "https://mobile-api.rokt.com/v1/experiences")!
        var mock = Mock(url: experienceURL, dataType: .json, statusCode: 200, data: [
            .post: Data("{\"placements\":[]}".utf8)
        ])
        mock.onRequest = { request, _ in
            capturedRequest = request
            expectation.fulfill()
        }
        mock.register()

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        RoktNetWorkAPI.getExperienceData(
            params: ["test": "value"],
            roktTagId: "test-tag-id",
            trackingConsent: nil,
            pageIdentifier: nil,
            onRequestStart: nil,
            successLayout: nil,
            failure: nil
        )

        waitForExpectations(timeout: 2.0, handler: nil)

        XCTAssertNotNil(capturedRequest)
        XCTAssertNil(capturedRequest?.allHTTPHeaderFields?[Self.BE_HEADER_PAGE_IDENTIFIER_KEY])
    }

    func test_RoktAPIHelper_passes_viewName_as_pageIdentifier() {
        let expectation = self.expectation(description: "RoktAPIHelper passes viewName to network layer")
        var capturedRequest: URLRequest?

        let experienceURL = URL(string: "https://mobile-api.rokt.com/v1/experiences")!
        var mock = Mock(url: experienceURL, dataType: .json, statusCode: 200, data: [
            .post: Data("{\"placements\":[]}".utf8)
        ])
        mock.onRequest = { request, _ in
            capturedRequest = request
            expectation.fulfill()
        }
        mock.register()

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        RoktAPIHelper.getExperienceData(
            viewName: "my-view",
            attributes: [:],
            roktTagId: "123123123",
            selectionId: "123123",
            trackingConsent: nil,
            config: RoktConfig.Builder().colorMode(.light).build(),
            onRequestStart: nil,
            successLayout: nil,
            failure: nil
        )

        waitForExpectations(timeout: 2.0, handler: nil)

        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.allHTTPHeaderFields?[Self.BE_HEADER_PAGE_IDENTIFIER_KEY], "my-view")
    }

}
