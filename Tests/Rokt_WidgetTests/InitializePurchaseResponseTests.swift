import XCTest
@testable import Rokt_Widget

final class InitializePurchaseResponseTests: XCTestCase {
    func test_decode_mapsPayPalData_whenPresent() throws {
        let json = """
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
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(InitializePurchaseResponse.self, from: json)
        XCTAssertEqual(decoded.paypalData?.orderId, "5O190127TN364715T")
        XCTAssertEqual(
            decoded.paypalData?.approvalUrl,
            "https://www.paypal.com/checkoutnow?token=5O190127TN364715T"
        )
    }

    func test_decode_setsPayPalDataNil_whenKeyAbsent() throws {
        let json = """
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
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(InitializePurchaseResponse.self, from: json)
        XCTAssertNil(decoded.paypalData)
    }
}
