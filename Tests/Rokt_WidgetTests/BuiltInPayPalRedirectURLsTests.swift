import XCTest
@testable import Rokt_Widget

final class BuiltInPayPalRedirectURLsTests: XCTestCase {
    func test_returnAndCancelURLs_composesBareSchemeAndFixedHosts() {
        let (returnURL, cancelURL) = BuiltInPayPalRedirectURLs.returnAndCancelURLs(forBareScheme: "myapp")
        XCTAssertEqual(returnURL, "myapp://rokt-paypal-return")
        XCTAssertEqual(cancelURL, "myapp://rokt-paypal-cancel")
    }

    func test_returnAndCancelURLs_trimsWhitespace() {
        let (returnURL, cancelURL) = BuiltInPayPalRedirectURLs.returnAndCancelURLs(forBareScheme: "  com.partner  ")
        XCTAssertEqual(returnURL, "com.partner://rokt-paypal-return")
        XCTAssertEqual(cancelURL, "com.partner://rokt-paypal-cancel")
    }

    func test_isValidBareScheme_rejectsFullURL() {
        XCTAssertFalse(PayPalRedirectURLSchemeValidator.isValidBareScheme("myapp://rokt-paypal-return"))
        XCTAssertFalse(PayPalRedirectURLSchemeValidator.isValidBareScheme("myapp/path"))
    }

    func test_isValidBareScheme_acceptsBareScheme() {
        XCTAssertTrue(PayPalRedirectURLSchemeValidator.isValidBareScheme("myapp"))
        XCTAssertTrue(PayPalRedirectURLSchemeValidator.isValidBareScheme("com.partner.app"))
    }
}
