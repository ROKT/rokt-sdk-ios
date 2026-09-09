import XCTest
@testable import RoktPaymentExtension

final class StripeAccountIdTests: XCTestCase {

    func testAcceptsStripeAccountIdShapes() {
        let accepted = [
            "acct_1A2b3C4d5E6f7G8h",
            "acct_mock_123",
            "acct_1",
            "acct_" + String(repeating: "Z", count: 64)
        ]
        for id in accepted {
            XCTAssertTrue(StripeAccountId.isValid(id), "expected \(id) to be accepted")
        }
    }

    func testRejectsNonAccountShapes() {
        let rejected = [
            "",
            "acct_",
            "acct",
            "merchant.com.test",
            "pk_test_dummy",
            "cus_123",
            "ACCT_123",
            " acct_123",
            "acct_123 ",
            "acct_12 3",
            "acct_1.2",
            "acct_1-2",
            "acct_1/2",
            "acct_é1",
            "acct_" + String(repeating: "Z", count: 65),
            String(repeating: "a", count: 200)
        ]
        for id in rejected {
            XCTAssertFalse(StripeAccountId.isValid(id), "expected \(id.debugDescription) to be rejected")
        }
    }
}
