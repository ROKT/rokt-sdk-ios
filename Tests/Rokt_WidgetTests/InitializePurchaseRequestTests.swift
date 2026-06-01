import XCTest
@testable import Rokt_Widget

final class InitializePurchaseRequestTests: XCTestCase {
    func test_toDictionary_omitsPaymentMethodTypeAndProviderWhenNil() {
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
            paymentMethodType: nil,
            paymentProvider: nil
        )

        let dict = request.toDictionary()

        XCTAssertNil(dict["paymentMethodType"] as? String)
        XCTAssertNil(dict["paymentProvider"] as? String)
    }

    func test_toDictionary_includesPaymentMethodTypeAndProviderWhenSet() {
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
            paymentMethodType: "ApplePay",
            paymentProvider: "Stripe"
        )

        let dict = request.toDictionary()

        XCTAssertEqual(dict["paymentMethodType"] as? String, "ApplePay")
        XCTAssertEqual(dict["paymentProvider"] as? String, "Stripe")
    }
}
