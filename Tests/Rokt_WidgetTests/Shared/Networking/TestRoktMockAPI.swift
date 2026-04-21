import XCTest
@testable import Rokt_Widget

final class TestRoktMockAPI: XCTestCase {

    func test_initialize_enablesShoppableAdsFeatureFlags() {
        var capturedResponse: InitRespose?
        let expectation = expectation(description: "RoktMockAPI.initialize success")

        RoktMockAPI.initialize(
            roktTagId: "mock-tag",
            success: { response in
                capturedResponse = response
                expectation.fulfill()
            },
            failure: { _, _, _ in
                XCTFail("RoktMockAPI.initialize should not fail in happy path")
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 1.0)

        let flags = try? XCTUnwrap(capturedResponse?.featureFlags)
        XCTAssertEqual(flags?.isShoppableAdsEnabled(), true,
                       "Mock builds must expose both post-purchase flags so selectShoppableAds() can be exercised end-to-end.")
    }

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
