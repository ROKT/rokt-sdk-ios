import XCTest
@testable import Rokt_Widget
import Mocker

class TestNetworkingHelper: XCTestCase {

    private static let headerPageIdentifierKey = "rokt-page-identifier"
    private static let headerSessionIdKey = "rokt-session-id"

    private func makeForwardPaymentRequest() -> PurchaseRequest {
        let item = UpsellItem(
            cartItemId: "cart-id",
            catalogItemId: "catalog-id",
            quantity: 1,
            unitPrice: 9.99,
            totalPrice: 9.99,
            currency: "USD"
        )

        return PurchaseRequest(
            totalUpsellPrice: 9.99,
            currency: "USD",
            upsellItems: [item],
            paymentDetails: PurchasePaymentDetails(token: nil, partnerPaymentReference: "ref-1"),
            fulfillmentDetails: nil
        )
    }

    private func makeMockHTTPClient() -> RoktHTTPClient {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        return RoktHTTPClient(sessionConfiguration: configuration)
    }

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
        XCTAssertEqual(capturedRequest?.allHTTPHeaderFields?[Self.headerPageIdentifierKey], "test-page")
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
        XCTAssertNil(capturedRequest?.allHTTPHeaderFields?[Self.headerPageIdentifierKey])
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
        XCTAssertEqual(capturedRequest?.allHTTPHeaderFields?[Self.headerPageIdentifierKey], "my-view")
    }

    func test_initializePurchase_invokesFailure_whenTagIdMissing() {
        let expectation = expectation(description: "initializePurchase fails without tag id")
        let originalTagId = Rokt.shared.roktImplementation.roktTagId
        Rokt.shared.roktImplementation.roktTagId = nil

        defer {
            Rokt.shared.roktImplementation.roktTagId = originalTagId
        }

        let item = UpsellItem(
            cartItemId: "cart-id",
            catalogItemId: "catalog-id",
            quantity: 1,
            unitPrice: 9.99,
            totalPrice: 9.99,
            currency: "USD"
        )
        let shippingAttributes = ShippingAttributes(
            address1: "1 Main St",
            city: "New York",
            state: "NY",
            postalCode: "10001",
            country: "US"
        )

        RoktNetWorkAPI.initializePurchase(
            upsellItems: [item],
            shippingAttributes: shippingAttributes,
            success: { _ in
                XCTFail("Expected initializePurchase to fail when tag id is missing")
            },
            failure: { error, statusCode, response in
                let expectedError = "Missing Rokt tag ID for initialize-purchase request"
                XCTAssertEqual(error.localizedDescription, expectedError)
                XCTAssertNil(statusCode)
                XCTAssertEqual(response, expectedError)
                expectation.fulfill()
            }
        )

        waitForExpectations(timeout: 2.0)
    }

    func test_forwardPayment_invokesFailure_whenTagIdMissing() {
        let expectation = expectation(description: "forwardPayment fails without tag id")
        let originalTagId = Rokt.shared.roktImplementation.roktTagId
        Rokt.shared.roktImplementation.roktTagId = nil

        defer {
            Rokt.shared.roktImplementation.roktTagId = originalTagId
        }

        let item = UpsellItem(
            cartItemId: "cart-id",
            catalogItemId: "catalog-id",
            quantity: 1,
            unitPrice: 9.99,
            totalPrice: 9.99,
            currency: "USD"
        )
        let request = PurchaseRequest(
            totalUpsellPrice: 9.99,
            currency: "USD",
            upsellItems: [item],
            paymentDetails: PurchasePaymentDetails(token: nil, partnerPaymentReference: "ref-1"),
            fulfillmentDetails: nil
        )

        RoktNetWorkAPI.forwardPayment(
            request: request,
            success: { _ in
                XCTFail("Expected forwardPayment to fail when tag id is missing")
            },
            failure: { error, statusCode, response in
                let expectedError = "Missing Rokt tag ID for forward-payment request"
                XCTAssertEqual(error.localizedDescription, expectedError)
                XCTAssertNil(statusCode)
                XCTAssertEqual(response, expectedError)
                expectation.fulfill()
            }
        )

        waitForExpectations(timeout: 2.0)
    }

    func test_forwardPayment_decodesSuccess_andIncludesSessionIdHeader() {
        let expectation = expectation(description: "forwardPayment succeeds")
        var capturedRequest: URLRequest?
        let originalEnvironment = config.environment
        let originalTagId = Rokt.shared.roktImplementation.roktTagId
        let originalSessionId = Rokt.shared.roktImplementation.sessionManager.getCurrentSessionIdWithoutExpiring()

        defer {
            config.environment = originalEnvironment
            Rokt.shared.roktImplementation.roktTagId = originalTagId
            Rokt.shared.roktImplementation.sessionManager.updateSessionId(newSessionId: originalSessionId)
        }

        Rokt.setEnvironment(environment: .Stage)
        Rokt.shared.roktImplementation.roktTagId = "test-tag-id"
        Rokt.shared.roktImplementation.sessionManager.updateSessionId(newSessionId: "session-123")

        let purchaseURL = URL(string: "https://mobile-api.stage.rokt.com/v1/cart/purchase")!
        var mock = Mock(url: purchaseURL, dataType: .json, statusCode: 200, data: [
            .post: Data(#"{"success":true}"#.utf8)
        ])
        mock.onRequest = { request, _ in
            capturedRequest = request
        }
        mock.register()
        NetworkingHelper.shared.httpClient = makeMockHTTPClient()

        RoktNetWorkAPI.forwardPayment(
            request: makeForwardPaymentRequest(),
            success: { response in
                XCTAssertTrue(response.success)
                XCTAssertNil(response.reason)
                expectation.fulfill()
            },
            failure: { _, _, _ in
                XCTFail("Expected forwardPayment to decode a successful response")
            }
        )

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(
            capturedRequest?.allHTTPHeaderFields?[Self.headerSessionIdKey],
            "session-123"
        )
        XCTAssertEqual(
            capturedRequest?.allHTTPHeaderFields?[HTTPHeader.contentType],
            HTTPHeader.applicationJSON
        )
    }

    func test_forwardPayment_invokesFailure_whenResponseCannotBeDecoded() {
        let expectation = expectation(description: "forwardPayment decode failure")
        let originalEnvironment = config.environment
        let originalTagId = Rokt.shared.roktImplementation.roktTagId

        defer {
            config.environment = originalEnvironment
            Rokt.shared.roktImplementation.roktTagId = originalTagId
        }

        Rokt.setEnvironment(environment: .Stage)
        Rokt.shared.roktImplementation.roktTagId = "test-tag-id"

        let purchaseURL = URL(string: "https://mobile-api.stage.rokt.com/v1/cart/purchase")!
        let mock = Mock(url: purchaseURL, dataType: .json, statusCode: 200, data: [
            .post: Data(#"{"reason":"missing success"}"#.utf8)
        ])
        mock.register()
        NetworkingHelper.shared.httpClient = makeMockHTTPClient()

        RoktNetWorkAPI.forwardPayment(
            request: makeForwardPaymentRequest(),
            success: { _ in
                XCTFail("Expected forwardPayment to fail when decoding invalid JSON")
            },
            failure: { error, statusCode, response in
                XCTAssertEqual(
                    error.localizedDescription,
                    "Failed to parse forward-payment response"
                )
                XCTAssertEqual(statusCode, 200)
                XCTAssertEqual(response, "Failed to parse response")
                expectation.fulfill()
            }
        )

        waitForExpectations(timeout: 2.0)
    }

    func test_RoktAPIHelper_forwardPayment_usesNetworkPath_outsideMockEnvironment() {
        let expectation = expectation(description: "RoktAPIHelper forwards to network API")
        let originalEnvironment = config.environment
        let originalTagId = Rokt.shared.roktImplementation.roktTagId

        defer {
            config.environment = originalEnvironment
            Rokt.shared.roktImplementation.roktTagId = originalTagId
        }

        Rokt.setEnvironment(environment: .Stage)
        Rokt.shared.roktImplementation.roktTagId = "test-tag-id"

        let purchaseURL = URL(string: "https://mobile-api.stage.rokt.com/v1/cart/purchase")!
        let mock = Mock(url: purchaseURL, dataType: .json, statusCode: 200, data: [
            .post: Data(#"{"success":false,"reason":"Declined"}"#.utf8)
        ])
        mock.register()
        NetworkingHelper.shared.httpClient = makeMockHTTPClient()

        RoktAPIHelper.forwardPayment(
            request: makeForwardPaymentRequest(),
            success: { response in
                XCTAssertFalse(response.success)
                XCTAssertEqual(response.reason, "Declined")
                expectation.fulfill()
            },
            failure: { _, _, _ in
                XCTFail("Expected RoktAPIHelper.forwardPayment to use the network path")
            }
        )

        waitForExpectations(timeout: 2.0)
    }

}
