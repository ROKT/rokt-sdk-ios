import XCTest
@testable import RoktUXHelper

@available(iOS 15, *)
final class TransactionDataTests: XCTestCase {

    private let decoder = JSONDecoder()

    func test_decodes_full_payload() throws {
        let json = """
        {
            "shippingAddress": {
                "name": "",
                "address1": "123 Mock St",
                "address2": "Apt 4B",
                "city": "Mock City",
                "state": "CA",
                "stateCode": "",
                "country": "US",
                "countryCode": "",
                "zip": "90210"
            },
            "paymentType": "amex",
            "supportedPaymentMethods": [
                { "type": "CARD" },
                { "type": "APPLE_PAY" },
                { "type": "AFTERPAY" }
            ],
            "isPartnerManagedPurchase": false,
            "partnerPaymentReference": "hg206hsc",
            "confirmationRef": "hg206hsc",
            "metadata": {}
        }
        """.data(using: .utf8)!

        let sut = try decoder.decode(TransactionData.self, from: json)

        XCTAssertEqual(sut.shippingAddress?.address1, "123 Mock St")
        XCTAssertEqual(sut.shippingAddress?.zip, "90210")
        XCTAssertNil(sut.billingAddress)
        XCTAssertEqual(sut.paymentType, "amex")
        XCTAssertEqual(sut.supportedPaymentMethods?.map { $0.type }, [.card, .applePay, .afterpay])
        XCTAssertFalse(sut.isPartnerManagedPurchase)
        XCTAssertEqual(sut.partnerPaymentReference, "hg206hsc")
        XCTAssertEqual(sut.confirmationRef, "hg206hsc")
        XCTAssertEqual(sut.metadata, [:])
    }

    func test_decodes_minimal_payload() throws {
        let json = """
        {
            "isPartnerManagedPurchase": true,
            "metadata": { "foo": "bar" }
        }
        """.data(using: .utf8)!

        let sut = try decoder.decode(TransactionData.self, from: json)

        XCTAssertNil(sut.shippingAddress)
        XCTAssertNil(sut.billingAddress)
        XCTAssertNil(sut.paymentType)
        XCTAssertNil(sut.supportedPaymentMethods)
        XCTAssertTrue(sut.isPartnerManagedPurchase)
        XCTAssertNil(sut.partnerPaymentReference)
        XCTAssertNil(sut.confirmationRef)
        XCTAssertEqual(sut.metadata, ["foo": "bar"])
    }

    func test_missing_metadata_throws() {
        let json = """
        { "isPartnerManagedPurchase": false }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(TransactionData.self, from: json))
    }

    func test_unknown_payment_method_type_falls_back_to_unknown() throws {
        let json = """
        { "type": "CRYPTO" }
        """.data(using: .utf8)!

        let sut = try decoder.decode(PaymentMethod.self, from: json)

        XCTAssertEqual(sut.type, .unknown)
    }

    func test_offer_without_transaction_data_decodes() throws {
        let json = """
        {
            "campaignId": "c1",
            "creative": {
                "referralCreativeId": "r1",
                "instanceGuid": "i1",
                "copy": {},
                "token": "t1"
            }
        }
        """.data(using: .utf8)!

        let sut = try decoder.decode(OfferModel.self, from: json)

        XCTAssertNil(sut.transactionData)
    }

    func test_offer_decodes_transaction_data() throws {
        let json = """
        {
            "campaignId": "c1",
            "creative": {
                "referralCreativeId": "r1",
                "instanceGuid": "i1",
                "copy": {},
                "token": "t1"
            },
            "transactionData": {
                "isPartnerManagedPurchase": false,
                "metadata": {}
            }
        }
        """.data(using: .utf8)!

        let sut = try decoder.decode(OfferModel.self, from: json)

        XCTAssertNotNil(sut.transactionData)
        XCTAssertFalse(sut.transactionData?.isPartnerManagedPurchase ?? true)
    }
}
