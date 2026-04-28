import XCTest
@testable import Rokt_Widget

final class InitializePurchaseRequestTests: XCTestCase {
    func test_toDictionary_includesSnakeCasePaymentMethodAndProviderWhenSet() {
        let upsell = UpsellItem(
            cartItemId: "c1",
            catalogItemId: "cat1",
            quantity: 1,
            unitPrice: 10,
            totalPrice: 10,
            currency: "USD"
        )
        let request = InitializePurchaseRequest(
            totalUpsellPrice: 10,
            currency: "USD",
            upsellItems: [upsell],
            fulfillmentDetails: nil,
            returnURL: "myapp://return",
            cancelURL: "myapp://cancel",
            paymentMethod: "PAYPAL",
            paymentProvider: "PAYPAL"
        )

        let dict = request.toDictionary()

        XCTAssertEqual(dict["payment_method"] as? String, "PAYPAL")
        XCTAssertEqual(dict["payment_provider"] as? String, "PAYPAL")
    }

    func test_toDictionary_omitsPaymentMethodAndProviderWhenNil() {
        let upsell = UpsellItem(
            cartItemId: "c1",
            catalogItemId: "cat1",
            quantity: 1,
            unitPrice: 10,
            totalPrice: 10,
            currency: "USD"
        )
        let request = InitializePurchaseRequest(
            totalUpsellPrice: 10,
            currency: "USD",
            upsellItems: [upsell],
            fulfillmentDetails: nil,
            returnURL: nil,
            cancelURL: nil,
            paymentMethod: nil,
            paymentProvider: nil
        )

        let dict = request.toDictionary()

        XCTAssertNil(dict["payment_method"] as? String)
        XCTAssertNil(dict["payment_provider"] as? String)
    }
}
