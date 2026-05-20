import XCTest
@testable import Rokt_Widget

final class InitializePurchaseRequestTests: XCTestCase {
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

        XCTAssertNil(dict["paymentMethod"] as? String)
        XCTAssertNil(dict["paymentProvider"] as? String)
    }

    func test_toDictionary_includesPaymentMethodAndProviderWhenSet() {
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
            paymentMethod: "apple_pay",
            paymentProvider: "stripe"
        )

        let dict = request.toDictionary()

        XCTAssertEqual(dict["paymentMethod"] as? String, "apple_pay")
        XCTAssertEqual(dict["paymentProvider"] as? String, "stripe")
    }
}
