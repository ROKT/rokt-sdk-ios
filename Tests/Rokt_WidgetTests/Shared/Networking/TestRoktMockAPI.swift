import XCTest
@testable import Rokt_Widget

final class TestRoktMockAPI: XCTestCase {

    func test_forwardPayment_returnsSuccess_whenUsingMockEnvironment() {
        let expectation = expectation(description: "RoktAPIHelper.forwardPayment mock success")
        let originalEnvironment = config.environment

        defer {
            config.environment = originalEnvironment
        }

        config.environment = .Mock

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

        RoktAPIHelper.forwardPayment(
            request: request,
            success: { response in
                XCTAssertTrue(response.success)
                XCTAssertNil(response.reason)
                expectation.fulfill()
            },
            failure: { _, _, _ in
                XCTFail("Mock forwardPayment should not fail in happy path")
            }
        )

        wait(for: [expectation], timeout: 1.0)
    }
}
