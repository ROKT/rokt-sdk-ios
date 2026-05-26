import XCTest
@testable import Rokt_Widget

final class InitializePurchaseResponseTests: XCTestCase {
    func test_decode_mapsPayPalData_whenPresent() throws {
        let json = Data("""
        {
          "success": true,
          "totalUpsellPrice": 10,
          "currency": "USD",
          "upsellItems": [{
            "cartItemId": "c1",
            "catalogItemId": "cat1",
            "quantity": 1,
            "unitPrice": 10,
            "totalPrice": 10,
            "currency": "USD"
          }],
          "paymentDetails": {
            "gateway": "paypal",
            "merchantAccountId": "acct",
            "clientSecret": "secret",
            "shippingCost": 0,
            "tax": 0,
            "totalAmount": 10
          },
          "paypalData": {
            "orderId": "5O190127TN364715T",
            "approvalUrl": "https://www.paypal.com/checkoutnow?token=5O190127TN364715T"
          }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(InitializePurchaseResponse.self, from: json)
        XCTAssertEqual(decoded.paypalData?.orderId, "5O190127TN364715T")
        XCTAssertEqual(
            decoded.paypalData?.approvalUrl,
            "https://www.paypal.com/checkoutnow?token=5O190127TN364715T"
        )
    }

    func test_decode_setsPayPalDataNil_whenKeyAbsent() throws {
        let json = Data("""
        {
          "success": true,
          "totalUpsellPrice": 10,
          "currency": "USD",
          "upsellItems": [{
            "cartItemId": "c1",
            "catalogItemId": "cat1",
            "quantity": 1,
            "unitPrice": 10,
            "totalPrice": 10,
            "currency": "USD"
          }],
          "paymentDetails": {
            "gateway": "stripe",
            "merchantAccountId": "acct",
            "clientSecret": "secret",
            "shippingCost": 0,
            "tax": 0,
            "totalAmount": 10
          }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(InitializePurchaseResponse.self, from: json)
        XCTAssertNil(decoded.paypalData)
    }

    func test_decodeFromCommercePurchasesAPI_mapsPayPalSnakeCase() throws {
        let json = Data(
            """
            {
              "id": "550e8400-e29b-41d4-a716-446655440000",
              "status": "PENDING",
              "totals": {
                "total_amount": "19.88",
                "shipping_fee": "5.00",
                "tax": "1.12",
                "currency": "USD"
              },
              "display_details": { "merchant_name": "Test Merchant" },
              "payment_provider": {
                "kind": "paypal",
                "paypal": {
                  "order_id": "5O190127TN364715T",
                  "approval_url": "https://www.paypal.com/checkoutnow?token=5O190127TN364715T"
                }
              }
            }
            """.utf8
        )

        let decoded = try InitializePurchaseResponse.decodeFromCommercePurchasesAPI(data: json)
        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.currency, "USD")
        XCTAssertEqual(decoded.paypalData?.orderId, "5O190127TN364715T")
        XCTAssertEqual(decoded.paymentDetails.gateway, "paypal")
        XCTAssertNil(decoded.paymentDetails.clientSecret)
    }
}
