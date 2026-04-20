import XCTest
@testable import Rokt_Widget

final class TestPurchaseRequest: XCTestCase {

    private func makeItem(
        cartItemId: String = "v1:abc:partner",
        catalogItemId: String = "cat-1",
        quantity: Decimal = 1,
        unitPrice: Decimal = 19.88,
        totalPrice: Decimal = 19.88,
        currency: String = "USD"
    ) -> UpsellItem {
        UpsellItem(
            cartItemId: cartItemId,
            catalogItemId: catalogItemId,
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            currency: currency
        )
    }

    func test_toDictionary_includesTopLevelFields() {
        let request = PurchaseRequest(
            totalUpsellPrice: 19.88,
            currency: "USD",
            upsellItems: [makeItem()],
            paymentDetails: PurchasePaymentDetails(token: nil, partnerPaymentReference: "ref-1"),
            fulfillmentDetails: nil
        )

        let dict = request.toDictionary()

        XCTAssertEqual(dict["totalUpsellPrice"] as? Decimal, 19.88)
        XCTAssertEqual(dict["currency"] as? String, "USD")
        XCTAssertNotNil(dict["upsellItems"])
        XCTAssertNotNil(dict["paymentDetails"])
        XCTAssertNil(dict["fulfillmentDetails"])
    }

    func test_toDictionary_serializesUpsellItems() {
        let request = PurchaseRequest(
            totalUpsellPrice: 19.88,
            currency: "USD",
            upsellItems: [makeItem()],
            paymentDetails: PurchasePaymentDetails(token: nil, partnerPaymentReference: "ref-1"),
            fulfillmentDetails: nil
        )

        let items = request.toDictionary()["upsellItems"] as? [[String: Any]]
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?.first?["cartItemId"] as? String, "v1:abc:partner")
        XCTAssertEqual(items?.first?["catalogItemId"] as? String, "cat-1")
        XCTAssertEqual(items?.first?["currency"] as? String, "USD")
    }

    func test_toDictionary_includesPaymentDetails() {
        let request = PurchaseRequest(
            totalUpsellPrice: 19.88,
            currency: "USD",
            upsellItems: [makeItem()],
            paymentDetails: PurchasePaymentDetails(
                token: "tok-123",
                partnerPaymentReference: "ref-1"
            ),
            fulfillmentDetails: nil
        )

        let paymentDetails = request.toDictionary()["paymentDetails"] as? [String: Any]
        XCTAssertEqual(paymentDetails?["token"] as? String, "tok-123")
        XCTAssertEqual(paymentDetails?["partnerPaymentReference"] as? String, "ref-1")
    }

    func test_toDictionary_omitsTokenWhenNil() {
        let details = PurchasePaymentDetails(token: nil, partnerPaymentReference: "ref-1")
        let dict = details.toDictionary()
        XCTAssertNil(dict["token"])
        XCTAssertEqual(dict["partnerPaymentReference"] as? String, "ref-1")
    }

    func test_toDictionary_omitsPartnerPaymentReferenceWhenNil() {
        let details = PurchasePaymentDetails(token: "tok-123", partnerPaymentReference: nil)
        let dict = details.toDictionary()
        XCTAssertNil(dict["partnerPaymentReference"])
        XCTAssertEqual(dict["token"] as? String, "tok-123")
    }

    func test_toDictionary_producesJSONSerializableOutput() throws {
        let shipping = ShippingAttributes(
            address1: "1 Main St",
            city: "NYC",
            state: "NY",
            postalCode: "10001",
            country: "USA",
            address2: nil,
            firstName: nil,
            lastName: nil,
            companyName: nil,
            countryCode: nil
        )
        let request = PurchaseRequest(
            totalUpsellPrice: 19.88,
            currency: "USD",
            upsellItems: [makeItem()],
            paymentDetails: PurchasePaymentDetails(
                token: "tok-123",
                partnerPaymentReference: "ref-1"
            ),
            fulfillmentDetails: FulfillmentDetails(shippingAttributes: shipping)
        )

        XCTAssertNoThrow(
            try JSONSerialization.data(withJSONObject: request.toDictionary(), options: [])
        )
    }

    func test_toDictionary_includesFulfillmentDetailsWhenPresent() {
        let shipping = ShippingAttributes(
            address1: "1 Main St",
            city: "NYC",
            state: "NY",
            postalCode: "10001",
            country: "USA",
            address2: nil,
            firstName: nil,
            lastName: nil,
            companyName: nil,
            countryCode: nil
        )
        let request = PurchaseRequest(
            totalUpsellPrice: 19.88,
            currency: "USD",
            upsellItems: [makeItem()],
            paymentDetails: PurchasePaymentDetails(token: nil, partnerPaymentReference: "ref-1"),
            fulfillmentDetails: FulfillmentDetails(shippingAttributes: shipping)
        )

        XCTAssertNotNil(request.toDictionary()["fulfillmentDetails"])
    }
}
