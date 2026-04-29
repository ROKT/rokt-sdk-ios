import XCTest
import UIKit
import RoktContracts

@testable import Rokt_Widget

// MARK: - Mock

final class MockPaymentExtension: PaymentExtension {
    let id: String
    let extensionDescription: String
    let supportedMethods: [String]

    var shouldRegisterSuccessfully: Bool = true
    var shouldAutomaticallyCompletePayment: Bool = true
    var paymentResultToReturn: PaymentSheetResult = .succeeded(transactionId: "txn_mock")
    var urlCallbackHandler: ((URL) -> Bool)?

    private(set) var onRegisterCallCount = 0
    private(set) var onRegisterLastParameters: [String: String]?
    private(set) var onUnregisterCallCount = 0
    private(set) var presentPaymentSheetCallCount = 0
    private(set) var presentPaymentSheetLastMethod: PaymentMethodType?
    private(set) var presentPaymentSheetLastItem: PaymentItem?
    private(set) var capturedPreparePayment: ((ContactAddress, @escaping (PaymentPreparation?, Error?) -> Void) -> Void)?
    private(set) var handleURLCallbackCallCount = 0
    private(set) var handleURLCallbackLastURL: URL?

    init(
        id: String = "mock_extension",
        extensionDescription: String = "Mock Payment Extension",
        supportedMethods: [PaymentMethodType] = [.applePay]
    ) {
        self.id = id
        self.extensionDescription = extensionDescription
        self.supportedMethods = supportedMethods.map { $0.wireValue }
    }

    func onRegister(parameters: [String: String]) -> Bool {
        onRegisterCallCount += 1
        onRegisterLastParameters = parameters
        return shouldRegisterSuccessfully
    }

    func onUnregister() {
        onUnregisterCallCount += 1
    }

    func presentPaymentSheet(
        item: PaymentItem,
        method: PaymentMethodType,
        context: PaymentContext,
        from viewController: UIViewController,
        preparePayment: @escaping (ContactAddress, @escaping (PaymentPreparation?, Error?) -> Void) -> Void,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        presentPaymentSheetCallCount += 1
        presentPaymentSheetLastMethod = method
        presentPaymentSheetLastItem = item
        capturedPreparePayment = preparePayment
        if shouldAutomaticallyCompletePayment {
            completion(paymentResultToReturn)
        }
    }

    func handleURLCallback(with url: URL) -> Bool {
        handleURLCallbackCallCount += 1
        handleURLCallbackLastURL = url
        return urlCallbackHandler?(url) ?? false
    }
}

/// Keeps the PayPal sheet open until a separate deep-link simulation runs (for testing ``PaymentOrchestrator/handleURLCallback(with:)``).
final class HoldingPayPalApprovalPresenter: PayPalApprovalPresenting {
    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    ) {
        _ = approvalURL
        _ = viewController
        _ = checkoutCoordinator
    }
}

final class MockPayPalApprovalPresenter: PayPalApprovalPresenting {
    private(set) var presentCallCount = 0
    private(set) var lastApprovalURL: URL?
    var sheetResult: PaymentSheetResult = .succeeded(transactionId: "mock_paypal_txn")

    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    ) {
        presentCallCount += 1
        lastApprovalURL = approvalURL
        DispatchQueue.main.async {
            checkoutCoordinator.completeFromEmbeddedCheckout(self.sheetResult)
        }
    }
}

// MARK: - Tests

class TestPaymentOrchestrator: XCTestCase {

    private var sut: PaymentOrchestrator!

    override func setUp() {
        super.setUp()
        PaymentOrchestrator.resetBuiltInPayPalDeferredStateForTesting()
        sut = PaymentOrchestrator()
        PaymentOrchestratorAPIHelperSpy.reset()
    }

    override func tearDown() {
        sut = nil
        PaymentOrchestrator.resetBuiltInPayPalDeferredStateForTesting()
        PaymentOrchestratorAPIHelperSpy.reset()
        super.tearDown()
    }

    private func paypalDeviceSessionForTests(
        onConfirmation: ((String, String, [String: String]) -> Void)? = nil
    ) -> BuiltInPayPalDevicePaySession {
        BuiltInPayPalDevicePaySession(layoutId: "test_layout", catalogItemId: "test_catalog") { lid, cid, data in
            onConfirmation?(lid, cid, data)
        }
    }

    // MARK: - Registration

    func test_register_success() {
        let ext = MockPaymentExtension()
        let result = sut.register(ext, config: ["key": "value"])

        XCTAssertTrue(result)
        XCTAssertEqual(ext.onRegisterCallCount, 1)
        XCTAssertEqual(ext.onRegisterLastParameters, ["key": "value"])
        XCTAssertNotNil(sut.paymentExtension(id: ext.id))
    }

    func test_register_failure_whenOnRegisterReturnsFalse() {
        let ext = MockPaymentExtension()
        ext.shouldRegisterSuccessfully = false

        let result = sut.register(ext, config: [:])

        XCTAssertFalse(result)
        XCTAssertNil(sut.paymentExtension(id: ext.id))
    }

    func test_register_duplicateId_replacesPreviousExtension() {
        let first = MockPaymentExtension(id: "stripe", supportedMethods: [.applePay])
        let second = MockPaymentExtension(id: "stripe", supportedMethods: [.card])

        sut.register(first, config: [:])
        sut.register(second, config: [:])

        let found = sut.paymentExtension(id: "stripe")
        XCTAssertTrue(found === second, "Should reference the second (replacement) extension")
        XCTAssertEqual(first.onUnregisterCallCount, 1)
        XCTAssertEqual(sut.availablePaymentMethods(), [.card])
    }

    func test_register_duplicateId_removesOldEvenWhenNewFails() {
        let first = MockPaymentExtension(id: "stripe")
        sut.register(first, config: [:])

        let second = MockPaymentExtension(id: "stripe")
        second.shouldRegisterSuccessfully = false
        sut.register(second, config: [:])

        XCTAssertEqual(first.onUnregisterCallCount, 1)
        XCTAssertNil(sut.paymentExtension(id: "stripe"),
                     "Old extension should be removed even when new one fails registration")
    }

    // MARK: - Lookup by ID

    func test_paymentExtension_byId_found() {
        let ext = MockPaymentExtension(id: "stripe")
        sut.register(ext, config: [:])

        XCTAssertTrue(sut.paymentExtension(id: "stripe") === ext)
    }

    func test_paymentExtension_byId_notFound() {
        XCTAssertNil(sut.paymentExtension(id: "nonexistent"))
    }

    // MARK: - Lookup by Supported Method

    func test_paymentExtensions_supportingMethod_returnsMatches() {
        let applePayExt = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        let cardExt = MockPaymentExtension(id: "ext2", supportedMethods: [.card])
        let bothExt = MockPaymentExtension(id: "ext3", supportedMethods: [.applePay, .card])

        sut.register(applePayExt, config: [:])
        sut.register(cardExt, config: [:])
        sut.register(bothExt, config: [:])

        let applePayExtensions = sut.paymentExtensions(supporting: .applePay)
        XCTAssertEqual(applePayExtensions.count, 2)

        let cardExtensions = sut.paymentExtensions(supporting: .card)
        XCTAssertEqual(cardExtensions.count, 2)
    }

    func test_paymentExtensions_supportingMethod_returnsEmpty_whenNoneMatch() {
        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        sut.register(ext, config: [:])

        XCTAssertTrue(sut.paymentExtensions(supporting: .card).isEmpty)
    }

    // MARK: - hasRegisteredExtension

    func test_hasRegisteredExtension_false_whenEmpty() {
        XCTAssertFalse(sut.hasRegisteredExtension)
    }

    func test_hasRegisteredExtension_true_afterRegistration() {
        sut.register(MockPaymentExtension(), config: [:])
        XCTAssertTrue(sut.hasRegisteredExtension)
    }

    // MARK: - availablePaymentMethods

    func test_availablePaymentMethods_empty_whenNoExtensions() {
        XCTAssertTrue(sut.availablePaymentMethods().isEmpty)
    }

    func test_availablePaymentMethods_deduplicatesAcrossExtensions() {
        let ext1 = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay, .card])
        let ext2 = MockPaymentExtension(id: "ext2", supportedMethods: [.applePay])

        sut.register(ext1, config: [:])
        sut.register(ext2, config: [:])

        let methods = sut.availablePaymentMethods()
        XCTAssertEqual(Set(methods), Set([.applePay, .card]))
        XCTAssertEqual(methods.count, 2, "Should not contain duplicates")
    }

    // MARK: - handleURLCallback

    func test_handleURLCallback_noExtensions_returnsFalse() {
        let url = URL(string: "myapp://stripe-redirect")!
        XCTAssertFalse(sut.handleURLCallback(with: url))
    }

    func test_handleURLCallback_noExtensionClaims_returnsFalse() {
        let ext1 = MockPaymentExtension(id: "ext1")
        let ext2 = MockPaymentExtension(id: "ext2")
        ext1.urlCallbackHandler = { _ in false }
        ext2.urlCallbackHandler = { _ in false }
        sut.register(ext1, config: [:])
        sut.register(ext2, config: [:])

        let url = URL(string: "myapp://foo")!
        XCTAssertFalse(sut.handleURLCallback(with: url))
        XCTAssertEqual(ext1.handleURLCallbackCallCount, 1)
        XCTAssertEqual(ext2.handleURLCallbackCallCount, 1)
        XCTAssertEqual(ext1.handleURLCallbackLastURL, url)
    }

    func test_handleURLCallback_firstClaims_shortCircuits() {
        let ext1 = MockPaymentExtension(id: "ext1")
        let ext2 = MockPaymentExtension(id: "ext2")
        ext1.urlCallbackHandler = { _ in true }
        ext2.urlCallbackHandler = { _ in true }
        sut.register(ext1, config: [:])
        sut.register(ext2, config: [:])

        let url = URL(string: "myapp://stripe-redirect")!
        XCTAssertTrue(sut.handleURLCallback(with: url))
        XCTAssertEqual(ext1.handleURLCallbackCallCount, 1)
        XCTAssertEqual(ext2.handleURLCallbackCallCount, 0, "second extension should not be called")
    }

    func test_handleURLCallback_secondClaims_returnsTrue() {
        let ext1 = MockPaymentExtension(id: "ext1")
        let ext2 = MockPaymentExtension(id: "ext2")
        ext1.urlCallbackHandler = { _ in false }
        ext2.urlCallbackHandler = { _ in true }
        sut.register(ext1, config: [:])
        sut.register(ext2, config: [:])

        let url = URL(string: "myapp://paypal-return")!
        XCTAssertTrue(sut.handleURLCallback(with: url))
        XCTAssertEqual(ext1.handleURLCallbackCallCount, 1)
        XCTAssertEqual(ext2.handleURLCallbackCallCount, 1)
    }

    // MARK: - processPayment

    func test_processPayment_routesToCorrectExtension() {
        let applePayExt = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        let cardExt = MockPaymentExtension(id: "ext2", supportedMethods: [.card])
        cardExt.paymentResultToReturn = .succeeded(transactionId: "txn_card")

        sut.register(applePayExt, config: [:])
        sut.register(cardExt, config: [:])

        let expectation = expectation(description: "Payment completes")
        let item = PaymentItem(id: "item1", name: "Widget", amount: 9.99, currency: "USD")
        let vc = UIViewController()

        sut
            .processPayment(method: .card, item: item, context: PaymentContext(), cartItemId: "v1:cart-123:canal",
                            from: vc) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            XCTAssertEqual(result.transactionId, "txn_card")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(applePayExt.presentPaymentSheetCallCount, 0)
        XCTAssertEqual(cardExt.presentPaymentSheetCallCount, 1)
        XCTAssertEqual(cardExt.presentPaymentSheetLastMethod, .card)
        XCTAssertEqual(cardExt.presentPaymentSheetLastItem?.id, "item1")
    }

    func test_processPayment_noMatchingExtension_returnsFailed() {
        let expectation = expectation(description: "Payment completes with failure")
        let item = PaymentItem(id: "item1", name: "Widget", amount: 9.99, currency: "USD")
        let vc = UIViewController()

        sut
            .processPayment(method: .applePay, item: item, context: PaymentContext(), cartItemId: "v1:cart-456:canal",
                            from: vc) { result in
            XCTAssertEqual(result.outcome, .failed)
            XCTAssertTrue(result.errorMessage?.contains("No payment extension found") == true,
                          "Error should indicate no extension found, got: \(result.errorMessage ?? "nil")")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func test_processPayment_preparePayment_plumbsTotalAmountTaxAndShipping() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])

        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = InitializePurchaseResponse(
            success: true,
            totalUpsellPrice: 80,
            currency: "USD",
            upsellItems: [],
            paymentDetails: PaymentDetails(
                gateway: "stripe",
                merchantName: "Test Merchant",
                merchantAccountId: "acct_test",
                paymentIntentId: "pi_test",
                clientSecret: "cs_test",
                shippingCost: Decimal(string: "0")!,
                tax: Decimal(string: "3.53")!,
                totalAmount: Decimal(string: "83.53")!
            ),
            paypalData: nil
        )

        let item = PaymentItem(id: "item1", name: "Widget", amount: 80, currency: "USD")
        sut.processPayment(
            method: .applePay,
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-abc:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called in this test")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment returns preparation with server amounts")
        let address = ContactAddress(name: "Jane Doe", email: "jane@example.com")
        preparePayment(address) { preparation, error in
            XCTAssertNil(error)
            XCTAssertNotNil(preparation)
            XCTAssertEqual(preparation?.clientSecret, "cs_test")
            XCTAssertEqual(preparation?.merchantId, "acct_test")
            XCTAssertEqual(preparation?.totalAmount, NSDecimalNumber(string: "83.53"))
            XCTAssertEqual(preparation?.shippingCost, NSDecimalNumber.zero)
            XCTAssertEqual(preparation?.tax, NSDecimalNumber(string: "3.53"))
            XCTAssertNil(preparation?.approvalUrl)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethod)
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider)
    }

    func test_processPayment_preparePayment_plumbsApprovalUrlWhenPayPalDataPresent() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])

        let approvalURL = "https://www.paypal.com/checkoutnow?token=TESTTOKEN"
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = InitializePurchaseResponse(
            success: true,
            totalUpsellPrice: 10,
            currency: "USD",
            upsellItems: [],
            paymentDetails: PaymentDetails(
                gateway: "paypal",
                merchantName: nil,
                merchantAccountId: "acct_pp",
                paymentIntentId: nil,
                clientSecret: "cs_pp",
                shippingCost: 0,
                tax: 0,
                totalAmount: 10
            ),
            paypalData: InitializePurchasePayPalData(orderId: "ORDER1", approvalUrl: approvalURL)
        )

        let item = PaymentItem(id: "item1", name: "Widget", amount: 10, currency: "USD")
        sut.processPayment(
            method: .applePay,
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-approval:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called in this test")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment includes PayPal approval URL")
        let address = ContactAddress(name: "Jane Doe", email: "jane@example.com")
        preparePayment(address) { preparation, error in
            XCTAssertNil(error)
            XCTAssertNotNil(preparation)
            XCTAssertEqual(preparation?.approvalUrl, approvalURL)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethod)
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider)
    }

    func test_processPayment_payPal_routesToBuiltInFlowWithoutExtension() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let expectation = expectation(description: "PayPal prepares then invokes approval presenter")
        let item = PaymentItem(id: "item1", name: "Widget", amount: 9.99, currency: "USD")
        let billing = ContactAddress(
            name: "Bo User",
            email: "bo@example.com",
            addressLine1: "1 Main St",
            city: "NYC",
            state: "NY",
            postalCode: "10001",
            country: "US"
        )
        let context = PaymentContext(
            billingAddress: billing,
            shippingAddress: nil,
            returnURL: "myapp://paypal/success",
            cancelURL: "myapp://paypal/cancel"
        )

        // Hold the presenting VC strongly: ``PendingBuiltInPayPalWebCheckout/presentingViewController``
        // is weak, and the deferred ``DispatchQueue.main.async`` in
        // ``presentPendingBuiltInPayPalAfterForwardPaymentSuccessIfNeeded`` would otherwise see nil.
        let viewController = UIViewController()
        sut.processPayment(
            method: .paypal,
            item: item,
            context: context,
            cartItemId: "v1:cart-paypal:canal",
            from: viewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            XCTAssertEqual(result.transactionId, "mock_paypal_txn")
            expectation.fulfill()
        }
        sut.presentPendingBuiltInPayPalAfterForwardPaymentSuccessIfNeeded()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.initializePurchaseCallCount, 1)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseReturnURL, "myapp://paypal/success")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseCancelURL, "myapp://paypal/cancel")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethod, "PAYPAL")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "PAYPAL")
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)
        XCTAssertEqual(payPalPresenter.lastApprovalURL?.absoluteString, "https://www.paypal.com/checkoutnow?token=MOCK")
    }

    func test_processPayment_payPal_passesReturnAndCancelURLToInitializePurchase() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let expectation = expectation(description: "PayPal prepare completes")
        let billing = ContactAddress(name: "Bo", email: "b@o.com")
        let context = PaymentContext(
            billingAddress: billing,
            shippingAddress: nil,
            returnURL: "myapp://paypal/success",
            cancelURL: "myapp://paypal/cancel"
        )

        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: context,
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { _ in
            expectation.fulfill()
        }
        sut.presentPendingBuiltInPayPalAfterForwardPaymentSuccessIfNeeded()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseReturnURL, "myapp://paypal/success")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseCancelURL, "myapp://paypal/cancel")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethod, "PAYPAL")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "PAYPAL")
    }

    func test_processPayment_payPal_ignoresRegisteredExtensionSupportingPayPal() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let ext = MockPaymentExtension(id: "ext_paypal", supportedMethods: [.paypal, .applePay])
        sut.register(ext, config: [:])

        let billing = ContactAddress(name: "Bo", email: "b@o.com")
        let paypalExpectation = expectation(description: "PayPal built-in prepare")
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: billing,
                shippingAddress: nil,
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { _ in
            paypalExpectation.fulfill()
        }
        sut.presentPendingBuiltInPayPalAfterForwardPaymentSuccessIfNeeded()
        wait(for: [paypalExpectation], timeout: 1.0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethod, "PAYPAL")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "PAYPAL")
        XCTAssertEqual(ext.presentPaymentSheetCallCount, 0, "PayPal must not use PaymentExtension.presentPaymentSheet")

        let appleExpectation = expectation(description: "Apple Pay still uses extension")
        sut.processPayment(
            method: .applePay,
            item: PaymentItem(id: "a1", name: "A", amount: 2, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:2",
            from: UIViewController()
        ) { _ in
            appleExpectation.fulfill()
        }
        wait(for: [appleExpectation], timeout: 1.0)
        XCTAssertEqual(ext.presentPaymentSheetCallCount, 1)
    }

    func test_availablePaymentMethods_includesPayPalWhenNoExtensionsRegistered() {
        let methods = sut.availablePaymentMethods()
        XCTAssertTrue(methods.contains(.paypal))
    }

    func test_handleURLCallback_builtinPayPalPlaceholder_defersToExtensions() {
        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.card])
        ext.urlCallbackHandler = { _ in true }
        sut.register(ext, config: [:])

        let url = URL(string: "myapp://paypal-return")!
        XCTAssertTrue(sut.handleURLCallback(with: url))
        XCTAssertEqual(ext.handleURLCallbackCallCount, 1)
    }

    func test_processPayment_preparePaymentFailsFast_whenResponseMissingRequiredFields() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])

        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = InitializePurchaseResponse(
            success: true,
            totalUpsellPrice: 9.99,
            currency: "USD",
            upsellItems: [],
            paymentDetails: PaymentDetails(
                gateway: "stripe",
                merchantName: "Test Merchant",
                merchantAccountId: "merchant.com.test",
                paymentIntentId: "pi_test",
                clientSecret: nil,
                shippingCost: 0,
                tax: 0,
                totalAmount: 9.99
            ),
            paypalData: nil
        )

        let item = PaymentItem(id: "item1", name: "Widget", amount: 9.99, currency: "USD")
        sut.processPayment(
            method: .applePay,
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-789:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called when the mock extension captures preparePayment only")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment returns validation error")
        let address = ContactAddress(name: "Jane Doe", email: "jane@example.com")
        preparePayment(address) { preparation, error in
            XCTAssertNil(preparation)
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.localizedDescription, PaymentOrchestrator.paymentPreparationResponseValidationError)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsMessage, PaymentOrchestrator.devicePayErrorCode)
            XCTAssertEqual(
                PaymentOrchestratorAPIHelperSpy.lastDiagnosticsCallStack,
                PaymentOrchestrator.paymentPreparationResponseValidationError
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethod)
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider)
    }

    private static func validInitializePurchaseResponse() -> InitializePurchaseResponse {
        InitializePurchaseResponse(
            success: true,
            totalUpsellPrice: 9.99,
            currency: "USD",
            upsellItems: [],
            paymentDetails: PaymentDetails(
                gateway: "stripe",
                merchantName: "Test",
                merchantAccountId: "merchant.com.test",
                paymentIntentId: "pi_test",
                clientSecret: "cs_test_secret",
                shippingCost: 0,
                tax: 0,
                totalAmount: 9.99
            ),
            paypalData: nil
        )
    }

    /// Includes ``InitializePurchasePayPalData/approvalUrl`` so built-in PayPal can present the hosted approve flow.
    private static func validPayPalInitializePurchaseResponse() -> InitializePurchaseResponse {
        InitializePurchaseResponse(
            success: true,
            totalUpsellPrice: 9.99,
            currency: "USD",
            upsellItems: [],
            paymentDetails: PaymentDetails(
                gateway: "stripe",
                merchantName: "Test",
                merchantAccountId: "merchant.com.test",
                paymentIntentId: "pi_test",
                clientSecret: "cs_test_secret",
                shippingCost: 0,
                tax: 0,
                totalAmount: 9.99
            ),
            paypalData: InitializePurchasePayPalData(
                orderId: "ORDER_MOCK",
                approvalUrl: "https://www.paypal.com/checkoutnow?token=MOCK"
            )
        )
    }

    func test_processPayment_payPal_failsWhenApprovalUrlMissing() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let expectation = expectation(description: "PayPal fails without approval URL")
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(billingAddress: ContactAddress(name: "A", email: "a@b.com"), returnURL: "myapp://ok"),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { result in
            XCTAssertEqual(result.outcome, .failed)
            XCTAssertEqual(result.errorMessage, PaymentOrchestrator.payPalApprovalURLMissingMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(payPalPresenter.presentCallCount, 0)
    }

    func test_processPayment_payPal_failsWhenDevicePaySessionMissing() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let expectation = expectation(description: "PayPal fails without device-pay session")
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: UIViewController()
        ) { result in
            XCTAssertEqual(result.outcome, .failed)
            XCTAssertEqual(result.errorMessage, PaymentOrchestrator.builtInPayPalMissingDeferredSessionMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(payPalPresenter.presentCallCount, 0)
        XCTAssertNil(PaymentOrchestrator.pendingBuiltInPayPalApprovalURL)
    }

    func test_handleURLCallback_completesPayPal_whenActiveCheckoutMatchesReturnDeepLink() {
        let presenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: presenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let expectation = expectation(description: "PayPal completes via deep link callback")
        // Hold the presenting VC strongly: ``PendingBuiltInPayPalWebCheckout/presentingViewController``
        // is weak, and the deferred main-queue dispatch in ``presentPendingBuiltInPayPalAfterForwardPaymentSuccessIfNeeded``
        // would otherwise see nil and complete with .failed before the deep link arrives.
        let viewController = UIViewController()
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: viewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            XCTAssertEqual(result.transactionId, "ORDER_FROM_LINK")
            expectation.fulfill()
        }
        sut.presentPendingBuiltInPayPalAfterForwardPaymentSuccessIfNeeded()

        // Disambiguate from the local `expectation` var declared above, which shadows
        // ``XCTestCase/expectation(description:)`` and produced a build error in Brandon's commit.
        let flush = self.expectation(description: "main queue flush for deferred PayPal coordinator")
        DispatchQueue.main.async { flush.fulfill() }
        wait(for: [flush], timeout: 1.0)

        let deepLink = URL(string: "myapp://paypal/success?token=ORDER_FROM_LINK")!
        XCTAssertTrue(sut.handleURLCallback(with: deepLink))

        wait(for: [expectation], timeout: 2.0)
    }

    func test_processPayment_payPal_failsWhenReturnURLMissing() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let expectation = expectation(description: "PayPal fails without return URL")
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(billingAddress: ContactAddress(name: "A", email: "a@b.com")),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { result in
            XCTAssertEqual(result.outcome, .failed)
            XCTAssertEqual(result.errorMessage, PaymentOrchestrator.payPalReturnURLMissingMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(payPalPresenter.presentCallCount, 0)
    }
}

class PaymentOrchestratorAPIHelperSpy: RoktAPIHelper {
    static var initializePurchaseResponse: InitializePurchaseResponse?
    static var initializePurchaseCallCount = 0
    static var lastInitializePurchaseReturnURL: String?
    static var lastInitializePurchaseCancelURL: String?
    static var lastInitializePurchasePaymentMethod: String?
    static var lastInitializePurchasePaymentProvider: String?
    static var sendDiagnosticsCallCount = 0
    static var lastDiagnosticsMessage: String?
    static var lastDiagnosticsCallStack: String?

    static func reset() {
        initializePurchaseResponse = nil
        initializePurchaseCallCount = 0
        lastInitializePurchaseReturnURL = nil
        lastInitializePurchaseCancelURL = nil
        lastInitializePurchasePaymentMethod = nil
        lastInitializePurchasePaymentProvider = nil
        sendDiagnosticsCallCount = 0
        lastDiagnosticsMessage = nil
        lastDiagnosticsCallStack = nil
    }

    override class func initializePurchase(
        upsellItems: [UpsellItem],
        shippingAttributes: ShippingAttributes,
        returnURL: String? = nil,
        cancelURL: String? = nil,
        paymentMethod: String? = nil,
        paymentProvider: String? = nil,
        success: ((InitializePurchaseResponse) -> Void)?,
        failure: ((Error, Int?, String) -> Void)?
    ) {
        initializePurchaseCallCount += 1
        lastInitializePurchaseReturnURL = returnURL
        lastInitializePurchaseCancelURL = cancelURL
        lastInitializePurchasePaymentMethod = paymentMethod
        lastInitializePurchasePaymentProvider = paymentProvider
        if let initializePurchaseResponse {
            success?(initializePurchaseResponse)
        } else {
            let error = NSError(
                domain: "RoktSDK",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing test initializePurchase response"]
            )
            failure?(error, 500, "Missing test initializePurchase response")
        }
    }

    override class func sendDiagnostics(
        message: String,
        callStack: String,
        severity: Severity = .error,
        sessionId: String? = nil,
        campaignId: String? = nil,
        additionalInfo: [String: Any] = [:],
        success: (() -> Void)? = nil,
        failure: ((Error, Int?, String) -> Void)? = nil
    ) {
        sendDiagnosticsCallCount += 1
        lastDiagnosticsMessage = message
        lastDiagnosticsCallStack = callStack
        success?()
    }
}
