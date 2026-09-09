import XCTest
@testable import RoktPaymentExtension
import RoktContracts

final class RoktPaymentExtensionTests: XCTestCase {

    // MARK: - init: at-least-one-configured guard

    func testInitWithNoParamsReturnsNil() {
        XCTAssertNil(RoktPaymentExtension())
    }

    func testInitWithEmptyMerchantIdOnlyReturnsNil() {
        XCTAssertNil(RoktPaymentExtension(applePayMerchantId: ""))
    }

    func testInitWithEmptyUrlSchemeOnlyReturnsNil() {
        XCTAssertNil(RoktPaymentExtension(urlScheme: ""))
    }

    func testInitWithBothEmptyReturnsNil() {
        XCTAssertNil(RoktPaymentExtension(applePayMerchantId: "", urlScheme: ""))
    }

    // MARK: - Apple Pay only

    func testInitWithApplePayOnly() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")
        XCTAssertNotNil(ext)
        XCTAssertEqual(ext?.supportedMethods, ["apple_pay", "card"])
    }

    func testInitWithApplePayAndCustomCountryCode() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test", countryCode: "AU")
        XCTAssertNotNil(ext)
    }

    // MARK: - Afterpay only

    func testInitWithAfterpayOnly() {
        let ext = RoktPaymentExtension(
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )
        XCTAssertNotNil(ext)
        XCTAssertEqual(ext?.supportedMethods, ["afterpay_clearpay"])
    }

    // MARK: - Both

    func testInitWithBothMethods() {
        let ext = RoktPaymentExtension(
            applePayMerchantId: "merchant.test",
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )
        XCTAssertNotNil(ext)
        XCTAssertEqual(ext?.supportedMethods, ["apple_pay", "card", "afterpay_clearpay"])
    }

    // MARK: - Universal-link return URL

    private let universalLink = URL(string: "https://partner.example/rokt/return")!

    func testInitWithUniversalLinkOnlyEnablesAfterpay() {
        let ext = RoktPaymentExtension(
            universalLinkReturnURL: universalLink,
            bundle: makeBundleWithoutSchemes()
        )
        XCTAssertNotNil(ext)
        XCTAssertEqual(ext?.supportedMethods, ["afterpay_clearpay"])
    }

    func testInitWithUniversalLinkAndApplePay() {
        let ext = RoktPaymentExtension(
            applePayMerchantId: "merchant.test",
            universalLinkReturnURL: universalLink,
            bundle: makeBundleWithoutSchemes()
        )
        XCTAssertNotNil(ext)
        XCTAssertEqual(ext?.supportedMethods, ["apple_pay", "card", "afterpay_clearpay"])
    }

    func testInitWithBothSchemeAndUniversalLinkReturnsNil() {
        XCTAssertNil(RoktPaymentExtension(
            urlScheme: "myapp",
            universalLinkReturnURL: universalLink,
            bundle: makeBundle(withSchemes: ["myapp"])
        ))
        XCTAssertNil(RoktPaymentExtension(
            applePayMerchantId: "merchant.test",
            urlScheme: "myapp",
            universalLinkReturnURL: universalLink,
            bundle: makeBundle(withSchemes: ["myapp"])
        ))
    }

    func testInitWithInvalidUniversalLinkReturnsNil() {
        XCTAssertNil(RoktPaymentExtension(
            universalLinkReturnURL: URL(string: "http://partner.example/rokt/return")!,
            bundle: makeBundleWithoutSchemes()
        ))
        XCTAssertNil(RoktPaymentExtension(
            universalLinkReturnURL: URL(string: "myapp://rokt-payment-return")!,
            bundle: makeBundleWithoutSchemes()
        ))
        XCTAssertNil(RoktPaymentExtension(
            universalLinkReturnURL: URL(string: "https://partner.example/rokt/return?a=1")!,
            bundle: makeBundleWithoutSchemes()
        ))
    }

    func testInitWithUnregisteredSchemeReturnsNil() {
        XCTAssertNil(RoktPaymentExtension(
            urlScheme: "myapp",
            bundle: makeBundleWithoutSchemes()
        ))
    }

    func testIsValidUniversalLinkAcceptsPlainHTTPSURLs() {
        XCTAssertTrue(ReturnURLMatching.isValidUniversalLink(universalLink))
        XCTAssertTrue(ReturnURLMatching.isValidUniversalLink(URL(string: "https://partner.example")!))
        XCTAssertTrue(ReturnURLMatching.isValidUniversalLink(URL(string: "HTTPS://Partner.Example/x")!))
    }

    func testIsValidUniversalLinkRejectsOtherForms() {
        let rejected = [
            "http://partner.example/x",
            "myapp://rokt-payment-return",
            "https://partner.example/x?a=1",
            "https://partner.example/x#top",
            "https://user@partner.example/x",
            "https://user:pass@partner.example/x",
            "https:///x"
        ]
        for candidate in rejected {
            guard let url = URL(string: candidate) else {
                XCTFail("Expected a parseable URL for \(candidate)")
                continue
            }
            XCTAssertFalse(ReturnURLMatching.isValidUniversalLink(url), candidate)
        }
    }

    func testOnRegisterBuildsUniversalLinkReturnURL() {
        let ext = RoktPaymentExtension(
            universalLinkReturnURL: universalLink,
            bundle: makeBundleWithoutSchemes()
        )!
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_123"]))
        XCTAssertEqual(ext.stripeAfterpayManager?.returnURL, "https://partner.example/rokt/return")
    }

    func testOnRegisterBuildsCustomSchemeReturnURL() {
        let ext = RoktPaymentExtension(
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )!
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_123"]))
        XCTAssertEqual(ext.stripeAfterpayManager?.returnURL, "myapp://rokt-payment-return")
    }

    func testOnRegisterApplePayOnlyBuildsNoAfterpayManager() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_123"]))
        XCTAssertNil(ext.stripeAfterpayManager)
    }

    func testMatchesConfiguredReturnURLUniversalLinkIgnoresQuery() {
        let ext = RoktPaymentExtension(
            universalLinkReturnURL: universalLink,
            bundle: makeBundleWithoutSchemes()
        )!
        let returned = "https://partner.example/rokt/return?redirect_status=succeeded&payment_intent=pi_placeholder"
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: returned)!))
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "HTTPS://PARTNER.EXAMPLE/rokt/return")!))
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example/rokt/return/")!))
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example/rokt/return#done")!))

        for candidate in Self.nonMatchingUniversalLinkCallbacks {
            XCTAssertFalse(ext.matchesConfiguredReturnURL(URL(string: candidate)!), candidate)
        }
    }

    func testMatchesConfiguredReturnURLUniversalLinkWithoutPath() {
        let ext = RoktPaymentExtension(
            universalLinkReturnURL: URL(string: "https://partner.example")!,
            bundle: makeBundleWithoutSchemes()
        )!
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example/?redirect_status=succeeded")!))
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example?redirect_status=succeeded")!))
        XCTAssertFalse(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example/other")!))
    }

    func testMatchesConfiguredReturnURLUniversalLinkComparesPort() {
        let ext = RoktPaymentExtension(
            universalLinkReturnURL: URL(string: "https://partner.example:8443/rokt/return")!,
            bundle: makeBundleWithoutSchemes()
        )!
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example:8443/rokt/return?a=1")!))
        XCTAssertFalse(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example/rokt/return")!))
        XCTAssertFalse(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example:8444/rokt/return")!))
    }

    func testMatchesConfiguredReturnURLCustomSchemeRejectsUniversalLink() {
        let ext = RoktPaymentExtension(
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )!
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "myapp://rokt-payment-return")!))
        XCTAssertTrue(ext.matchesConfiguredReturnURL(URL(string: "MYAPP://rokt-payment-return?redirect_status=succeeded")!))
        XCTAssertFalse(ext.matchesConfiguredReturnURL(URL(string: "https://partner.example/rokt/return")!))
        XCTAssertFalse(ext.matchesConfiguredReturnURL(URL(string: "myapp://stripe-redirect")!))
    }

    func testHandleURLCallbackUniversalLinkRejectsNonMatching() {
        let ext = RoktPaymentExtension(
            universalLinkReturnURL: universalLink,
            bundle: makeBundleWithoutSchemes()
        )!
        for candidate in Self.nonMatchingUniversalLinkCallbacks {
            XCTAssertFalse(ext.handleURLCallback(with: URL(string: candidate)!), candidate)
        }
    }

    private static let nonMatchingUniversalLinkCallbacks = [
        "https://partner.example/rokt/other",
        "https://partner.example/rokt/return/extra",
        "https://partner.example/rokt",
        "https://partner.example/Rokt/Return",
        "https://other.example/rokt/return",
        "https://partner.example.other.example/rokt/return",
        "https://partner.example:8443/rokt/return",
        "http://partner.example/rokt/return",
        "myapp://rokt-payment-return",
        "https://rokt-payment-return"
    ]

    // MARK: - Protocol properties

    func testProtocolProperties() {
        let ext = RoktPaymentExtension(
            applePayMerchantId: "merchant.test",
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )!
        XCTAssertEqual(ext.id, "rokt-payment-extension")
        XCTAssertEqual(ext.extensionDescription, "Rokt Payment Extension")
    }

    // MARK: - onRegister / onUnregister

    func testOnRegisterWithoutStripeKeyReturnsFalse() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertFalse(ext.onRegister(parameters: [:]))
    }

    func testOnRegisterWithEmptyStripeKeyReturnsFalse() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertFalse(ext.onRegister(parameters: ["stripeKey": ""]))
    }

    func testOnRegisterWithValidKeyReturnsTrue() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_123"]))
    }

    func testOnUnregisterNilsManager() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_123"]))
        ext.onUnregister()
        XCTAssertTrue(ext.onRegister(parameters: ["stripeKey": "pk_test_456"]))
    }

    // MARK: - presentPaymentSheet error paths

    func testApplePayNotConfiguredRejectsTap() {
        let ext = RoktPaymentExtension(
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )!
        ext.onRegister(parameters: ["stripeKey": "pk_test_123"])

        let item = PaymentItem(id: "item-1", name: "Widget", amount: 10.00, currency: "USD")
        let expect = expectation(description: "completion")

        ext.presentPaymentSheet(
            item: item,
            method: .applePay,
            context: PaymentContext(),
            from: UIViewController(),
            preparePayment: { _, done in
                XCTFail("preparePayment should not be called when Apple Pay is not configured")
                done(nil, nil)
            },
            completion: { result in
                XCTAssertEqual(result.outcome, .failed)
                XCTAssertTrue(result.errorMessage?.contains("Apple Pay not configured") ?? false)
                expect.fulfill()
            }
        )

        waitForExpectations(timeout: 1)
    }

    func testAfterpayNotConfiguredRejectsTap() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        ext.onRegister(parameters: ["stripeKey": "pk_test_123"])

        let item = PaymentItem(id: "item-1", name: "Widget", amount: 10.00, currency: "USD")
        let context = PaymentContext(
            billingAddress: ContactAddress(name: "Test", email: "test@example.com")
        )
        let expect = expectation(description: "completion")

        ext.presentPaymentSheet(
            item: item,
            method: .afterpay,
            context: context,
            from: UIViewController(),
            preparePayment: { _, done in
                XCTFail("preparePayment should not be called when Afterpay is not configured")
                done(nil, nil)
            },
            completion: { result in
                XCTAssertEqual(result.outcome, .failed)
                XCTAssertTrue(result.errorMessage?.contains("Provide a urlScheme") ?? false)
                expect.fulfill()
            }
        )

        waitForExpectations(timeout: 1)
    }

    func testPaypalIsRejectedAsUnsupported() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        let item = PaymentItem(id: "item-1", name: "Widget", amount: 10.00, currency: "USD")
        let expect = expectation(description: "completion")

        ext.presentPaymentSheet(
            item: item,
            method: .paypal,
            context: PaymentContext(),
            from: UIViewController(),
            preparePayment: { _, done in
                XCTFail("preparePayment should not be called for unsupported methods")
                done(nil, nil)
            },
            completion: { result in
                XCTAssertEqual(result.outcome, .failed)
                XCTAssertEqual(result.errorMessage, "Unsupported payment method: paypal")
                expect.fulfill()
            }
        )

        waitForExpectations(timeout: 1)
    }

    // MARK: - Scheme validation helpers

    func testIsValidBareSchemeAcceptsBareScheme() {
        XCTAssertTrue(RoktPaymentExtension.isValidBareScheme("myapp"))
        XCTAssertTrue(RoktPaymentExtension.isValidBareScheme("com.partner.app"))
    }

    func testIsValidBareSchemeRejectsEmbeddedURL() {
        XCTAssertFalse(RoktPaymentExtension.isValidBareScheme(""))
        XCTAssertFalse(RoktPaymentExtension.isValidBareScheme("myapp://stripe-redirect"))
        XCTAssertFalse(RoktPaymentExtension.isValidBareScheme("myapp/something"))
    }

    func testIsValidBareSchemeRejectsWebSchemes() {
        XCTAssertFalse(RoktPaymentExtension.isValidBareScheme("https"))
        XCTAssertFalse(RoktPaymentExtension.isValidBareScheme("HTTP"))
    }

    func testIsSchemeRegisteredMatchesCaseInsensitive() {
        let b = makeBundle(withSchemes: ["MyApp"])
        XCTAssertTrue(RoktPaymentExtension.isSchemeRegistered("myapp", in: b))
        XCTAssertTrue(RoktPaymentExtension.isSchemeRegistered("MYAPP", in: b))
    }

    func testIsSchemeRegisteredReturnsFalseWhenMissing() {
        XCTAssertFalse(
            RoktPaymentExtension.isSchemeRegistered("myapp", in: makeBundle(withSchemes: ["other"]))
        )
        XCTAssertFalse(
            RoktPaymentExtension.isSchemeRegistered("myapp", in: makeBundleWithoutSchemes())
        )
    }

    // MARK: - handleURLCallback

    func testHandleURLCallbackApplePayOnlyAlwaysReturnsFalse() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        XCTAssertFalse(ext.handleURLCallback(with: URL(string: "myapp://rokt-payment-return")!))
        XCTAssertFalse(ext.handleURLCallback(with: URL(string: "anything://anything")!))
    }

    func testHandleURLCallbackRejectsWrongScheme() {
        let ext = RoktPaymentExtension(
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )!
        let url = URL(string: "other://rokt-payment-return")!
        XCTAssertFalse(ext.handleURLCallback(with: url))
    }

    func testHandleURLCallbackRejectsWrongHost() {
        let ext = RoktPaymentExtension(
            urlScheme: "myapp",
            bundle: makeBundle(withSchemes: ["myapp"])
        )!
        let url = URL(string: "myapp://stripe-redirect")!
        XCTAssertFalse(ext.handleURLCallback(with: url))
    }

    func testHandleURLCallbackReturnsFalseForUnrelatedURL() {
        let ext = RoktPaymentExtension(applePayMerchantId: "merchant.test")!
        let url = URL(string: "myapp://unrelated-callback")!
        XCTAssertFalse(ext.handleURLCallback(with: url))
    }
}
