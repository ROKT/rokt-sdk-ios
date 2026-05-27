import XCTest
@testable import Rokt_Widget

final class InitializePurchaseRequestTests: XCTestCase {
    func test_toCommercePurchasesDictionary_mapsPaymentMethodAndSnakeCase() {
        let upsell = UpsellItem(
            cartItemId: "c1",
            catalogItemId: "cat-guid-1",
            quantity: 1,
            unitPrice: 10,
            totalPrice: 10,
            currency: "USD"
        )
        let shipping = ShippingAttributes(
            address1: "1 Main St",
            city: "New York",
            state: "NY",
            postalCode: "10001",
            country: "US"
        )
        let request = InitializePurchaseRequest(
            sessionId: "sess-1",
            totalUpsellPrice: 10,
            currency: "USD",
            upsellItems: [upsell],
            fulfillmentDetails: FulfillmentDetails(shippingAttributes: shipping),
            returnURL: "myapp://return",
            cancelURL: "myapp://cancel",
            paymentMethod: "PAYPAL",
            paymentProvider: "PayPal"
        )

        let dict = request.toCommercePurchasesDictionary()

        XCTAssertEqual(dict["session_id"] as? String, "sess-1")
        XCTAssertEqual(dict["payment_method"] as? String, "PAYMENT_METHOD_PAYPAL")

        let lineItems = dict["line_items"] as? [[String: Any]]
        XCTAssertEqual(lineItems?.count, 1)
        XCTAssertEqual(lineItems?.first?["catalog_item_guid"] as? String, "c1")
        XCTAssertEqual(lineItems?.first?["quantity"] as? Int, 1)

        let shippingDetails = dict["shipping_details"] as? [String: Any]
        let address = shippingDetails?["address"] as? [String: Any]
        XCTAssertEqual(address?["address1"] as? String, "1 Main St")
        XCTAssertEqual(address?["province_code"] as? String, "NY")
        XCTAssertEqual(address?["country_code"] as? String, "US")
        XCTAssertEqual(address?["zip"] as? String, "10001")

        let redirect = dict["redirect_urls"] as? [String: Any]
        XCTAssertEqual(redirect?["return_url"] as? String, "myapp://return")
        XCTAssertEqual(redirect?["cancel_url"] as? String, "myapp://cancel")
    }

    func test_toCommercePurchasesDictionary_omitsRedirectUrlsWhenEitherURLMissing() {
        let upsell = UpsellItem(
            cartItemId: "c1",
            catalogItemId: "cat-1",
            quantity: 1,
            unitPrice: 10,
            totalPrice: 10,
            currency: "USD"
        )
        let request = InitializePurchaseRequest(
            sessionId: "sess-1",
            totalUpsellPrice: 10,
            currency: "USD",
            upsellItems: [upsell],
            fulfillmentDetails: nil,
            returnURL: "myapp://return",
            cancelURL: nil,
            paymentMethod: "CARD",
            paymentProvider: nil
        )

        let dict = request.toCommercePurchasesDictionary()
        XCTAssertNil(dict["redirect_urls"])
    }

    func test_toCommerceLineItem_fallsBackToCatalogItemIdWhenCartItemIdEmpty() {
        let upsell = UpsellItem(
            cartItemId: "",
            catalogItemId: "fallback-guid",
            quantity: 1,
            unitPrice: 10,
            totalPrice: 10,
            currency: "USD"
        )
        let dict = upsell.toCommerceLineItemDictionary()
        XCTAssertEqual(dict["catalog_item_guid"] as? String, "fallback-guid")
    }
}
