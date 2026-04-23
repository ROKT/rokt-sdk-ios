import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper
import Mocker

/// Verifies the shape of the `/v1/cart/purchase` request body produced by
/// `handleForwardPayment`. Both `paymentDetails.partnerPaymentReference`
/// and `fulfillmentDetails.shippingAttributes` must be sourced from
/// `event.transactionData` (exposed by rokt-ux-helper-ios 0.10.2), and
/// `fulfillmentDetails` must be omitted when no shipping address is present.
final class TestForwardPaymentRequestBody: XCTestCase {

    private let purchaseURL = URL(string: "https://mobile-api.rokt.com/v1/cart/purchase")!
    private let executeId = "test-execute-id"

    private var originalTagId: String?

    override func setUp() {
        super.setUp()
        Rokt.setEnvironment(environment: .Prod)
        originalTagId = Rokt.shared.roktImplementation.roktTagId
        Rokt.shared.roktImplementation.roktTagId = "test-tag-id"
    }

    override func tearDown() {
        Rokt.shared.roktImplementation.roktTagId = originalTagId
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeEvent(
        transactionData: TransactionData? = nil
    ) -> RoktUXEvent.CartItemForwardPayment {
        RoktUXEvent.CartItemForwardPayment(
            layoutId: "layout-1",
            name: "Test item",
            cartItemId: "cart-1",
            catalogItemId: "catalog-1",
            currency: "USD",
            description: "desc",
            linkedProductId: nil,
            providerData: "provider",
            quantity: 1,
            totalPrice: 9.99,
            unitPrice: 9.99,
            transactionData: transactionData
        )
    }

    private func makeImplementation() -> RoktInternalImplementation {
        let impl = RoktInternalImplementation()
        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: { _ in })
        impl.stateManager.addState(id: executeId, state: bag)
        return impl
    }

    private func installMockingHTTPClient() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)
    }

    // MARK: - Tests

    func test_purchaseBody_shippingAttributes_sourcedFromTransactionData() throws {
        let impl = makeImplementation()

        let address = RoktUXHelper.Address(
            name: "Ignored Name",
            address1: "123 Mock St",
            address2: "Apt 4B",
            city: "Mock City",
            state: "California",
            stateCode: "CA",
            country: "United States",
            countryCode: "US",
            zip: "90210"
        )
        let transactionData = TransactionData(
            shippingAddress: address,
            billingAddress: nil,
            paymentType: nil,
            supportedPaymentMethods: nil,
            isPartnerManagedPurchase: false,
            partnerPaymentReference: "ref-xyz",
            confirmationRef: nil,
            metadata: [:]
        )

        let requestCaptured = expectation(description: "/cart/purchase request captured")
        var capturedBody: [String: Any]?

        var mock = Mock(
            url: purchaseURL,
            dataType: .json,
            statusCode: 200,
            data: [.post: Data("{\"success\":true}".utf8)]
        )
        mock.onRequest = { request, _ in
            capturedBody = request.bodyStreamAsJSON() as? [String: Any]
            requestCaptured.fulfill()
        }
        mock.register()
        installMockingHTTPClient()

        impl.handleForwardPayment(
            executeId: executeId,
            event: makeEvent(transactionData: transactionData)
        )

        wait(for: [requestCaptured], timeout: 2.0)

        let body = try XCTUnwrap(capturedBody)
        let paymentDetails = try XCTUnwrap(body["paymentDetails"] as? [String: Any])
        XCTAssertEqual(paymentDetails["partnerPaymentReference"] as? String, "ref-xyz")
        XCTAssertNil(paymentDetails["token"], "token must be omitted when not supplied")

        let fulfillment = try XCTUnwrap(body["fulfillmentDetails"] as? [String: Any])
        let shipping = try XCTUnwrap(fulfillment["shippingAttributes"] as? [String: Any])
        XCTAssertEqual(shipping["address1"] as? String, "123 Mock St")
        XCTAssertEqual(shipping["address2"] as? String, "Apt 4B")
        XCTAssertEqual(shipping["city"] as? String, "Mock City")
        XCTAssertEqual(shipping["state"] as? String, "CA", "should prefer stateCode over state")
        XCTAssertEqual(shipping["country"] as? String, "US", "should prefer countryCode over country")
        XCTAssertEqual(shipping["postalCode"] as? String, "90210")
        XCTAssertNil(shipping["firstName"], "name fields must not leak into shippingAttributes")
        XCTAssertNil(shipping["lastName"], "name fields must not leak into shippingAttributes")
    }

    func test_purchaseBody_noFulfillment_whenTransactionDataShippingAddressMissing() throws {
        let impl = makeImplementation()

        // transactionData is nil (shippingAddress therefore absent).
        let requestCaptured = expectation(description: "/cart/purchase request captured")
        var capturedBody: [String: Any]?

        var mock = Mock(
            url: purchaseURL,
            dataType: .json,
            statusCode: 200,
            data: [.post: Data("{\"success\":true}".utf8)]
        )
        mock.onRequest = { request, _ in
            capturedBody = request.bodyStreamAsJSON() as? [String: Any]
            requestCaptured.fulfill()
        }
        mock.register()
        installMockingHTTPClient()

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [requestCaptured], timeout: 2.0)

        let body = try XCTUnwrap(capturedBody)
        XCTAssertNil(
            body["fulfillmentDetails"],
            "fulfillmentDetails key must be omitted when transactionData.shippingAddress is absent"
        )
    }
}
