import XCTest
@testable import Rokt_Widget

final class TestPurchaseResponse: XCTestCase {

    func test_decodes_successTrueWithoutReason() throws {
        let json = Data(#"{ "success": true }"#.utf8)
        let response = try JSONDecoder().decode(PurchaseResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertNil(response.reason)
    }

    func test_decodes_successFalseWithReason() throws {
        let json = Data(#"{ "success": false, "reason": "PaymentDetailsInvalid" }"#.utf8)
        let response = try JSONDecoder().decode(PurchaseResponse.self, from: json)
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.reason, "PaymentDetailsInvalid")
    }

    func test_decodes_ignoresUnknownFields() throws {
        let json = Data(#"""
        {
          "success": true,
          "reason": null,
          "totalUpsellPrice": 19.88,
          "currency": "USD",
          "paid": true,
          "paymentDetails": { "method": "card", "message": "ok" },
          "shippingInitiated": false
        }
        """#.utf8)
        let response = try JSONDecoder().decode(PurchaseResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertNil(response.reason)
    }

    func test_decode_failsWhenSuccessMissing() {
        let json = Data(#"{ "reason": "x" }"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(PurchaseResponse.self, from: json))
    }
}
