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
        // Capture when the presenter is called so later changes to `sheetResult` (e.g. a retry
        // test switching to `.succeeded`) cannot affect an already-scheduled completion.
        let resultToDeliver = sheetResult
        DispatchQueue.main.async {
            checkoutCoordinator.completeFromUserDismissal(resultToDeliver)
        }
    }
}

// MARK: - Tests

class TestPaymentOrchestrator: XCTestCase {

    private var sut: PaymentOrchestrator!

    override func setUp() {
        super.setUp()
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
        sut = PaymentOrchestrator()
        PaymentOrchestratorAPIHelperSpy.reset()
    }

    override func tearDown() {
        sut = nil
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
        PaymentOrchestratorAPIHelperSpy.reset()
        super.tearDown()
    }

    private static let testExecuteId = "test_execute"

    private func paypalDeviceSessionForTests(
        onConfirmation: ((String, String, [String: String]) -> Void)? = nil
    ) -> BuiltInTwoStepDevicePaySession {
        BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "test_catalog"
        ) { lid, cid, data in
            onConfirmation?(lid, cid, data)
        }
    }

    /// Key under which the test sessions store Step-1 for `cartItemId`; Step-2 lookups must present the same key.
    private func testKey(cartItemId: String = "v1:cart:1") -> BuiltInTwoStepCheckoutKey {
        BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "test_catalog",
            cartItemId: cartItemId
        )
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
        XCTAssertEqual(Set(sut.availablePaymentMethods()), Set([.card, .paypal]))
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

    func test_availablePaymentMethods_builtinDefaults_whenNoExtensionsRegistered() {
        let methods = sut.availablePaymentMethods()
        XCTAssertEqual(Set(methods), Set([.card, .paypal]))
        XCTAssertEqual(methods.count, 2)
    }

    func test_availablePaymentMethods_excludesPayPalWhenBuiltInPayPalUnavailable() {
        let methods = sut.availablePaymentMethods(isBuiltInPayPalAvailable: false)
        XCTAssertEqual(Set(methods), Set([.card]))
        XCTAssertEqual(methods.count, 1)
    }

    func test_availablePaymentMethods_deduplicatesAcrossExtensions() {
        let ext1 = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay, .card])
        let ext2 = MockPaymentExtension(id: "ext2", supportedMethods: [.applePay])

        sut.register(ext1, config: [:])
        sut.register(ext2, config: [:])

        let methods = sut.availablePaymentMethods()
        XCTAssertEqual(Set(methods), Set([.applePay, .card, .paypal]))
        XCTAssertEqual(methods.count, 3, "Should not contain duplicates")
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

    func test_processPayment_extensionFailure_sendsDiagnostics() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.afterpay])
        ext.paymentResultToReturn = .failed(
            error: "The PaymentMethod provided is not allowed (Stripe paymentIntentId: pi_test123)"
        )
        sut.register(ext, config: [:])

        let expectation = expectation(description: "Payment completes with failure")
        let item = PaymentItem(id: "item1", name: "Widget", amount: 9.99, currency: "USD")

        sut.processPayment(
            method: .afterpay,
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-456:canal",
            from: UIViewController()
        ) { result in
            XCTAssertEqual(result.outcome, .failed)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsMessage, PaymentOrchestrator.devicePayErrorCode)
            XCTAssertEqual(
                PaymentOrchestratorAPIHelperSpy.lastDiagnosticsCallStack,
                "The PaymentMethod provided is not allowed (Stripe paymentIntentId: pi_test123)"
            )
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsSeverity, .warning)
            XCTAssertEqual(
                PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo?["paymentMethod"] as? String,
                PaymentMethodType.afterpay.wireValue
            )
            XCTAssertEqual(
                PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo?["cartItemId"] as? String,
                "v1:cart-456:canal"
            )
            XCTAssertEqual(
                PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo?["catalogItemId"] as? String,
                "item1"
            )
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
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "ApplePay")
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider)
    }

    func test_processPayment_preparePayment_includesContactAddressLine2InInitializePurchase() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.afterpay])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])

        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let item = PaymentItem(id: "item1", name: "Widget", amount: 49, currency: "USD")

        sut.processPayment(
            method: .afterpay,
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-address2:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called in this test")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment sends preserved shipping attributes")
        let contactAddress = ContactAddress(
            name: "Thomson Thomas",
            email: "thomson@example.com",
            addressLine1: "69-65 Yellowstone Blvd",
            addressLine2: "Apt 1101",
            city: "Forest Hills",
            state: "NY",
            postalCode: "11375",
            country: "US"
        )
        preparePayment(contactAddress) { preparation, error in
            XCTAssertNil(error)
            XCTAssertNotNil(preparation)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseShippingAttributes?.address1,
                       "69-65 Yellowstone Blvd")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseShippingAttributes?.address2, "Apt 1101")
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
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "ApplePay")
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
        // ``presentPendingBuiltInPayPalForForwardPayment(for:onCompletion:)`` would otherwise see nil.
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
        _ = sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey(cartItemId: "v1:cart-paypal:canal")) { _ in }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.initializePurchaseCallCount, 1)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseReturnURL, "myapp://paypal/success")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseCancelURL, "myapp://paypal/cancel")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Paypal")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "PayPal")
        // Tripwire against re-introducing the legacy lowercase tokens.
        XCTAssertNotEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "paypal")
        XCTAssertNotEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "paypal")
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
        _ = sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseReturnURL, "myapp://paypal/success")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseCancelURL, "myapp://paypal/cancel")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Paypal")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "PayPal")
    }

    func test_presentPendingBuiltInPayPal_canceledRestoresPendingAndDefersStep1Completion() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        payPalPresenter.sheetResult = .canceled
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        // ``PendingBuiltInPayPalWebCheckout/presentingViewController`` is weak; keep a strong ref
        // so ``presentPendingBuiltInPayPalForForwardPayment`` does not fall through to the
        // no-view-controller failure path before the mock can run.
        let presentingViewController = UIViewController()

        var step1Result: PaymentSheetResult?
        let billing = ContactAddress(name: "Bo", email: "b@o.com")
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: billing,
                returnURL: "myapp://paypal/success",
                cancelURL: "myapp://paypal/cancel"
            ),
            cartItemId: "v1:cart:1",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { result in
            step1Result = result
        }

        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in
            XCTFail("onCompletion must not run when hosted PayPal approval is canceled")
        })

        // ``presentPendingBuiltInPayPalForForwardPayment`` pops pending synchronously; the mock
        // presenter and ``PayPalCheckoutCoordinator`` each hop to the main queue before the
        // cancel path re-queues. One extra async is not enough — drain several turns so requeue
        // finishes before we assert or call ``presentPending`` again.
        for _ in 0..<8 {
            let flush = expectation(description: "main queue flush")
            DispatchQueue.main.async { flush.fulfill() }
            wait(for: [flush], timeout: 1.0)
        }
        XCTAssertNil(step1Result, "Deferred Step-1 completion must not run on hosted cancel")

        payPalPresenter.sheetResult = .succeeded(transactionId: "retry_ok")
        var forwardObserverResult: PaymentSheetResult?
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { result in
            forwardObserverResult = result
        })
        for _ in 0..<8 {
            let flush = expectation(description: "main queue flush after success")
            DispatchQueue.main.async { flush.fulfill() }
            wait(for: [flush], timeout: 1.0)
        }
        XCTAssertEqual(step1Result?.outcome, .succeeded)
        XCTAssertEqual(step1Result?.transactionId, "retry_ok")
        XCTAssertEqual(forwardObserverResult?.outcome, .succeeded)
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
        _ = sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in }
        wait(for: [paypalExpectation], timeout: 1.0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Paypal")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "PayPal")
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

    func test_availablePaymentMethods_includesCardForwardingWhenNoExtensionsRegistered() {
        let methods = sut.availablePaymentMethods()
        XCTAssertTrue(methods.contains(.card))
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
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "ApplePay")
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider)
    }

    // MARK: - Built-in Card forwarding (two-step)

    func test_processPayment_card_routesToBuiltInCardFlowWithoutExtension() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let confirmationExpectation = expectation(description: "Card showConfirmation fires after prepare")
        var confirmationData: [String: String]?
        let cardSession = BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "test_catalog"
        ) { _, _, data in
            confirmationData = data
            confirmationExpectation.fulfill()
        }

        let item = PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD")
        sut.processPayment(
            method: .card,
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-card:canal",
            from: UIViewController(),
            builtInCardDevicePaySession: cardSession
        ) { _ in
            // Step-1 completion is held until the forward-payment attempt finishes (see ``beginBuiltInCardForwardPaymentIfReady(for:)``).
            XCTFail("Card Step-1 completion fired before forward-payment terminal finish")
        }

        wait(for: [confirmationExpectation], timeout: 1.0)

        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.initializePurchaseCallCount, 1)
        // Built-in card forwarding passes `CARD` / `Card` as the cart wire values.
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Card")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "Card")
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseReturnURL)
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchaseCancelURL)
        XCTAssertNotNil(confirmationData)
    }

    func test_builtInCardForward_beginFinishTerminalSuccess_deliversCompletionAndClearsInFlight() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let confirmationExpectation = expectation(description: "Card showConfirmation fires")
        let cardSession = BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "test_catalog"
        ) { _, _, _ in
            confirmationExpectation.fulfill()
        }

        let stepOneCompletionExpectation = expectation(description: "Step-1 completion fires after terminal finish")
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart-card:canal",
            from: UIViewController(),
            builtInCardDevicePaySession: cardSession
        ) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            stepOneCompletionExpectation.fulfill()
        }
        wait(for: [confirmationExpectation], timeout: 1.0)

        guard sut.beginBuiltInCardForwardPaymentIfReady(for: testKey(cartItemId: "v1:cart-card:canal")) != nil else {
            XCTFail("Expected begin after prepare")
            return
        }
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())
        XCTAssertNil(
            sut.beginBuiltInCardForwardPaymentIfReady(for: testKey(cartItemId: "v1:cart-card:canal")),
            "Second begin must return nil while in flight"
        )

        sut.finishBuiltInCardForwardPaymentAttempt(
            for: testKey(cartItemId: "v1:cart-card:canal"),
            result: .succeeded(transactionId: "card_txn")
        )
        wait(for: [stepOneCompletionExpectation], timeout: 1.0)
        XCTAssertFalse(sut.isBuiltInCardForwardPaymentInFlight())
        XCTAssertNil(
            sut.beginBuiltInCardForwardPaymentIfReady(for: testKey(cartItemId: "v1:cart-card:canal")),
            "No pending card after terminal finish"
        )
    }

    func test_restoreBuiltInCardForwardPaymentAfterRetryableFailure_allowsSecondBegin() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let confirmationExpectation = expectation(description: "Card showConfirmation fires")
        let cardSession = BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "test_catalog"
        ) { _, _, _ in
            confirmationExpectation.fulfill()
        }

        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart-card:canal",
            from: UIViewController(),
            builtInCardDevicePaySession: cardSession
        ) { _ in
            XCTFail("Step-1 completion must not run until terminal finish")
        }
        wait(for: [confirmationExpectation], timeout: 1.0)

        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey(cartItemId: "v1:cart-card:canal")))
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())
        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: testKey(cartItemId: "v1:cart-card:canal"))
        XCTAssertFalse(sut.isBuiltInCardForwardPaymentInFlight())
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey(cartItemId: "v1:cart-card:canal")))
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())
    }

    func test_beginBuiltInCardForwardPaymentIfReady_returnsNilWhenCacheHoldsPayPal() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let viewController = UIViewController()
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "item-pp", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(
                billingAddress: nil,
                shippingAddress: nil,
                returnURL: "myapp://paypal/success",
                cancelURL: "myapp://paypal/cancel"
            ),
            cartItemId: "v1:cart-pp:canal",
            from: viewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { _ in }

        // PayPal cache is set for this item; built-in card begin must not apply to it.
        let payPalKey = testKey(cartItemId: "v1:cart-pp:canal")
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: payPalKey))
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: payPalKey) { _ in })
    }

    // MARK: - Deferred Step-1 state is bound to its item and placement

    func test_presentPendingBuiltInPayPal_otherItemKey_returnsFalseAndLeavesEntryIntact() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let presentingViewController = UIViewController()
        var stepOneResult: PaymentSheetResult?
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { stepOneResult = $0 }

        let otherItem = testKey(cartItemId: "v1:cart:2")
        let otherPlacement = BuiltInTwoStepCheckoutKey(
            executeId: "other_execute",
            layoutId: "test_layout",
            catalogItemId: "test_catalog",
            cartItemId: "v1:cart:1"
        )
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: otherItem) { _ in
            XCTFail("Another item's confirm must not resume this checkout")
        })
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: otherPlacement) { _ in
            XCTFail("Another placement's confirm must not resume this checkout")
        })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 0)
        XCTAssertNil(stepOneResult)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)
        XCTAssertEqual(stepOneResult?.outcome, .succeeded)
    }

    func test_beginBuiltInCardForwardPaymentIfReady_otherItemKey_returnsNilAndLeavesEntryIntact() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let confirmationExpectation = expectation(description: "Card showConfirmation fires")
        let cardSession = BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "test_catalog"
        ) { _, _, _ in
            confirmationExpectation.fulfill()
        }
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart-card:canal",
            from: UIViewController(),
            builtInCardDevicePaySession: cardSession
        ) { _ in
            XCTFail("Step-1 completion must not run until terminal finish")
        }
        wait(for: [confirmationExpectation], timeout: 1.0)

        let cardKey = testKey(cartItemId: "v1:cart-card:canal")
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey(cartItemId: "v1:cart-other:canal")))
        XCTAssertFalse(sut.isBuiltInCardForwardPaymentInFlight())
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: cardKey))

        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: cardKey))
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())
    }

    func test_stepOne_secondItem_keepsFirstItemPending() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "item-a", name: "A", amount: 1, currency: "USD"),
            context: PaymentContext(returnURL: "myapp://paypal/success", cancelURL: nil),
            cartItemId: "v1:cart-a:canal",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { _ in }

        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
        let confirmationExpectation = expectation(description: "Card showConfirmation fires for item B")
        let cardSession = BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "catalog_b"
        ) { _, _, _ in
            confirmationExpectation.fulfill()
        }
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-b", name: "B", amount: 2, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart-b:canal",
            from: UIViewController(),
            builtInCardDevicePaySession: cardSession
        ) { _ in
            XCTFail("Step-1 completion must not run until terminal finish")
        }
        wait(for: [confirmationExpectation], timeout: 1.0)

        let keyA = testKey(cartItemId: "v1:cart-a:canal")
        let keyB = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "catalog_b",
            cartItemId: "v1:cart-b:canal"
        )
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: keyA), "Item B's Step-1 must not replace item A's")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: keyB))
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: keyA), "Item A is PayPal, not card")
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: keyB))
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: keyA) { _ in })
    }

    func test_discardPendingBuiltInTwoStep_forExecuteId_dropsOnlyThatExecuteWithoutCompleting() {
        let keyA = BuiltInTwoStepCheckoutKey(executeId: "execute_a", layoutId: "l", catalogItemId: "c", cartItemId: "cart_a")
        let keyB = BuiltInTwoStepCheckoutKey(executeId: "execute_b", layoutId: "l", catalogItemId: "c", cartItemId: "cart_b")
        sut.unitTest_seedDeferredBuiltInPayPalForwardPayment(
            for: keyA,
            approvalURL: URL(string: "https://www.paypal.com/checkoutnow?token=MOCK")!,
            returnURLString: "myapp://paypal/success",
            orderId: "ORDER_A"
        ) { _ in
            XCTFail("Discard must not invoke the Step-1 completion")
        }
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: keyB) { _ in
            XCTFail("Another execute's entry must be untouched")
        }

        sut.discardPendingBuiltInTwoStep(forExecuteId: "execute_a", layoutId: "l")
        drainMainQueue()

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: keyA))
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: keyA) { _ in })
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: keyB))
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: keyB))
    }

    func test_discardPendingBuiltInTwoStep_forLayout_keepsAnotherOpenLayoutsCheckoutUnderTheSameExecute() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()
        // Held strongly until the deferred present has run; the pending checkout only keeps a weak reference.
        let presentingViewController = UIViewController()
        func startStepOne(layoutId: String, cartItemId: String, completion: @escaping (PaymentSheetResult) -> Void) {
            sut.processPayment(
                method: .paypal,
                item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
                context: PaymentContext(
                    billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                    returnURL: "myapp://paypal/success",
                    cancelURL: nil
                ),
                cartItemId: cartItemId,
                from: presentingViewController,
                builtInPayPalDevicePaySession: BuiltInTwoStepDevicePaySession(
                    executeId: Self.testExecuteId,
                    layoutId: layoutId,
                    catalogItemId: "test_catalog"
                ) { _, _, _ in },
                completion: completion
            )
        }
        startStepOne(layoutId: "closing_layout", cartItemId: "v1:cart:1") { _ in
            XCTFail("Discard must not invoke the Step-1 completion")
        }
        var openLayoutStepOneResult: PaymentSheetResult?
        startStepOne(layoutId: "open_layout", cartItemId: "v1:cart:2") { openLayoutStepOneResult = $0 }
        let closingKey = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId, layoutId: "closing_layout", catalogItemId: "test_catalog", cartItemId: "v1:cart:1"
        )
        let openKey = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId, layoutId: "open_layout", catalogItemId: "test_catalog", cartItemId: "v1:cart:2"
        )

        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "closing_layout")
        drainMainQueue()

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: closingKey))
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: closingKey) { _ in })
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: openKey), "The other open layout keeps its checkout")

        // The other layout's confirm still resumes its own checkout.
        var forwardObserverResult: PaymentSheetResult?
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: openKey) { forwardObserverResult = $0 })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)
        XCTAssertEqual(openLayoutStepOneResult?.outcome, .succeeded)
        XCTAssertEqual(forwardObserverResult?.outcome, .succeeded)
    }

    func test_discardPendingBuiltInTwoStep_forExecuteId_withoutALayoutId_dropsEveryLayoutUnderTheExecute() {
        let firstKey = BuiltInTwoStepCheckoutKey(
            executeId: "execute_a", layoutId: "l1", catalogItemId: "c", cartItemId: "cart_a"
        )
        let secondKey = BuiltInTwoStepCheckoutKey(
            executeId: "execute_a", layoutId: "l2", catalogItemId: "c", cartItemId: "cart_b"
        )
        let otherExecuteKey = BuiltInTwoStepCheckoutKey(
            executeId: "execute_b", layoutId: "l1", catalogItemId: "c", cartItemId: "cart_c"
        )
        for key in [firstKey, secondKey, otherExecuteKey] {
            sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: key) { _ in
                XCTFail("Discard must not invoke the Step-1 completion")
            }
        }

        // An event without a layout id cannot be scoped, so it fences the whole execute, as before.
        sut.discardPendingBuiltInTwoStep(forExecuteId: "execute_a", layoutId: nil)

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: firstKey))
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey))
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: otherExecuteKey), "Another execute keeps its checkout")
    }

    func test_discardPendingBuiltInTwoStep_forExecuteId_keepsARunningCardPurchaseUntilItsResultArrives() {
        let heldKey = BuiltInTwoStepCheckoutKey(executeId: "execute_a", layoutId: "l", catalogItemId: "c", cartItemId: "cart_a")
        let sentKey = BuiltInTwoStepCheckoutKey(executeId: "execute_a", layoutId: "l", catalogItemId: "c", cartItemId: "cart_b")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: heldKey) { _ in
            XCTFail("Discard must not invoke the Step-1 completion")
        }
        let sentResult = expectation(description: "The running card purchase still delivers its result")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: sentKey) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            sentResult.fulfill()
        }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: sentKey), "Item B's purchase is in flight")

        sut.discardPendingBuiltInTwoStep(forExecuteId: "execute_a", layoutId: "l")
        drainMainQueue()

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: heldKey), "A confirm not yet tapped goes with its layout")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: sentKey), "A purchase already sent keeps its completion")
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight(), "One cart purchase at a time still holds while it runs")

        sut.finishBuiltInCardForwardPaymentAttempt(for: sentKey, result: .succeeded(transactionId: ""))
        wait(for: [sentResult], timeout: 1.0)
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: sentKey))
        XCTAssertFalse(sut.isBuiltInCardForwardPaymentInFlight())
    }

    func test_discardAllPendingBuiltInTwoStep_dropsEntriesNotInFlightAndKeepsTheRunningCardPurchase() {
        let keyA = BuiltInTwoStepCheckoutKey(executeId: "execute_a", layoutId: "l", catalogItemId: "c", cartItemId: "cart_a")
        let keyB = BuiltInTwoStepCheckoutKey(executeId: "execute_b", layoutId: "l", catalogItemId: "c", cartItemId: "cart_b")
        sut.unitTest_seedDeferredBuiltInPayPalForwardPayment(
            for: keyA,
            approvalURL: URL(string: "https://www.paypal.com/checkoutnow?token=MOCK")!,
            returnURLString: "myapp://paypal/success",
            orderId: "ORDER_A"
        ) { _ in
            XCTFail("Discard must not invoke the Step-1 completion")
        }
        let inFlightResult = expectation(description: "The running card purchase still delivers its result")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: keyB) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            inFlightResult.fulfill()
        }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: keyB), "Item B is in flight when the session ends")

        sut.discardAllPendingBuiltInTwoStep()
        drainMainQueue()

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: keyA))
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: keyA) { _ in })
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: keyB), "A purchase already sent keeps its completion")
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight(), "One cart purchase at a time still holds while it runs")
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: keyB), "The running purchase is not started twice")

        sut.finishBuiltInCardForwardPaymentAttempt(for: keyB, result: .succeeded(transactionId: ""))
        wait(for: [inFlightResult], timeout: 1.0)
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: keyB))
        XCTAssertFalse(sut.isBuiltInCardForwardPaymentInFlight())
    }

    func test_cancelPendingBuiltInTwoStep_forKey_failsOnlyThatItem() {
        let keyA = BuiltInTwoStepCheckoutKey(executeId: "execute", layoutId: "l", catalogItemId: "c", cartItemId: "cart_a")
        let keyB = BuiltInTwoStepCheckoutKey(executeId: "execute", layoutId: "l", catalogItemId: "c", cartItemId: "cart_b")
        let canceled = expectation(description: "Item A's Step-1 completion fails")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: keyA) { result in
            XCTAssertEqual(result.outcome, .failed)
            canceled.fulfill()
        }
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: keyB) { _ in
            XCTFail("Cancelling item A must not touch item B")
        }

        sut.cancelPendingBuiltInTwoStep(for: keyA)

        wait(for: [canceled], timeout: 1.0)
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: keyA))
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: keyB))
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
    private static func validPayPalInitializePurchaseResponse(
        approvalUrl: String = "https://www.paypal.com/checkoutnow?token=MOCK",
        orderId: String = "ORDER_MOCK"
    ) -> InitializePurchaseResponse {
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
                orderId: orderId,
                approvalUrl: approvalUrl
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

    /// Runs Step-1 with the given approval URL and returns the failed result; fails the test if the
    /// confirm button is shown, the presenter is called, or anything is left pending.
    private func runPayPalStepOneExpectingRejection(approvalUrl: String) -> PaymentSheetResult? {
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
        PaymentOrchestratorAPIHelperSpy.reset()
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(approvalUrl: approvalUrl)

        var stepOneResult: PaymentSheetResult?
        let failed = expectation(description: "PayPal Step-1 fails for approval URL \(approvalUrl)")
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in
                XCTFail("Confirmation must not be shown for approval URL \(approvalUrl)")
            }
        ) { result in
            stepOneResult = result
            failed.fulfill()
        }
        wait(for: [failed], timeout: 1.0)

        XCTAssertEqual(payPalPresenter.presentCallCount, 0, approvalUrl)
        XCTAssertFalse(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in },
            "Nothing may stay pending: \(approvalUrl)"
        )
        return stepOneResult
    }

    func test_processPayment_payPal_failsWhenApprovalUrlIsNotWebURL() {
        for approvalUrl in ["myapp://x", "javascript:1", "file:///etc", "paypal.com/checkoutnow"] {
            let result = runPayPalStepOneExpectingRejection(approvalUrl: approvalUrl)

            XCTAssertEqual(result?.outcome, .failed, approvalUrl)
            XCTAssertEqual(result?.errorMessage, PaymentOrchestrator.payPalApprovalURLInvalidMessage, approvalUrl)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1, approvalUrl)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsMessage, PaymentOrchestrator.devicePayErrorCode)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsSeverity, .warning)
            let loggedStrings = (PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo ?? [:])
                .values.compactMap { $0 as? String }
            XCTAssertFalse(
                loggedStrings.contains { $0.contains(approvalUrl) },
                "Diagnostics must not carry the approval URL: \(approvalUrl)"
            )
        }
    }

    /// A web scheme without a host is rejected before the confirm button; whether `URL(string:)` parses these at
    /// all differs between Foundation versions, so either rejection message is acceptable.
    func test_processPayment_payPal_failsWhenApprovalUrlHasWebSchemeButNoHost() {
        for approvalUrl in ["https://", "https:///x"] {
            let result = runPayPalStepOneExpectingRejection(approvalUrl: approvalUrl)

            XCTAssertEqual(result?.outcome, .failed, approvalUrl)
            XCTAssertTrue(
                [
                    PaymentOrchestrator.payPalApprovalURLInvalidMessage,
                    PaymentOrchestrator.payPalApprovalURLMissingMessage
                ].contains(result?.errorMessage ?? ""),
                approvalUrl
            )
        }
    }

    func test_processPayment_payPal_acceptsHttpApprovalUrl() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(approvalUrl: "http://localhost:9011/approve")

        let completed = expectation(description: "PayPal completes with an http approval URL")
        let presentingViewController = UIViewController()
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            completed.fulfill()
        }
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })

        wait(for: [completed], timeout: 1.0)
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)
        XCTAssertEqual(payPalPresenter.lastApprovalURL?.absoluteString, "http://localhost:9011/approve")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 0)
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
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
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
        // is weak, and the deferred main-queue dispatch in ``presentPendingBuiltInPayPalForForwardPayment(for:onCompletion:)``
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
            // The surfaced transaction id is the order id from cart prepare, which the link must carry.
            XCTAssertEqual(result.transactionId, "ORDER_MOCK")
            expectation.fulfill()
        }
        _ = sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in }

        // Disambiguate from the local `expectation` var declared above, which shadows
        // ``XCTestCase/expectation(description:)`` and produced a build error in Brandon's commit.
        let flush = self.expectation(description: "main queue flush for deferred PayPal coordinator")
        DispatchQueue.main.async { flush.fulfill() }
        wait(for: [flush], timeout: 1.0)

        let deepLink = URL(string: "myapp://paypal/success?token=ORDER_MOCK")!
        XCTAssertTrue(sut.handleURLCallback(with: deepLink))

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Deep-link binding to the pending order

    private func drainMainQueue(turns: Int = 8) {
        for _ in 0..<turns {
            let flush = expectation(description: "main queue flush")
            DispatchQueue.main.async { flush.fulfill() }
            wait(for: [flush], timeout: 1.0)
        }
    }

    /// Starts built-in PayPal Step-1 with a presenter that holds the sheet open, presents the pending checkout
    /// and drains the main queue, so the checkout coordinator is active when a deep link is simulated.
    private func startHeldPayPalCheckout(
        cancelURL: String? = nil,
        onStepOneResult: @escaping (PaymentSheetResult) -> Void
    ) {
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: HoldingPayPalApprovalPresenter()
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        // Held strongly until the deferred present has run; the pending checkout only keeps a weak reference.
        let presentingViewController = UIViewController()
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: cancelURL
            ),
            cartItemId: "v1:cart:1",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { result in
            onStepOneResult(result)
        }
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        PaymentOrchestratorAPIHelperSpy.reset()
    }

    func test_handleURLCallback_payPalReturn_tokenForAnotherOrder_leavesCheckoutPending() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout { stepOneResult = $0 }

        let otherOrderLink = URL(string: "myapp://paypal/success?token=OTHER_ORDER")!
        XCTAssertTrue(sut.handleURLCallback(with: otherOrderLink), "The link is ours and must not reach payment extensions")
        drainMainQueue()

        XCTAssertNil(stepOneResult, "A return link for another order must not complete the checkout")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1)
        XCTAssertEqual(
            PaymentOrchestratorAPIHelperSpy.lastDiagnosticsCallStack,
            PaymentOrchestrator.payPalReturnLinkOrderMismatchMessage
        )
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo?["tokenPresent"] as? Bool, true)
        XCTAssertTrue(
            (PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo ?? [:]).values.allSatisfy { $0 is Bool },
            "Diagnostics carry flags only, never the link's token or the order id"
        )

        // The genuine redirect still completes the same pending checkout.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertEqual(stepOneResult?.outcome, .succeeded)
        XCTAssertEqual(stepOneResult?.transactionId, "ORDER_MOCK")
    }

    func test_handleURLCallback_payPalReturn_withoutToken_leavesCheckoutPending() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout { stepOneResult = $0 }

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success")!))
        drainMainQueue()

        XCTAssertNil(stepOneResult, "A return link without a token must not complete the checkout")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo?["tokenPresent"] as? Bool, false)

        // The genuine redirect still completes the same pending checkout.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertEqual(stepOneResult?.outcome, .succeeded)
        XCTAssertEqual(stepOneResult?.transactionId, "ORDER_MOCK")
    }

    func test_handleURLCallback_payPalCancel_tokenForAnotherOrder_leavesCheckoutPending() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout(cancelURL: "myapp://paypal/cancel") { stepOneResult = $0 }

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=OTHER_ORDER")!))
        drainMainQueue()

        XCTAssertNil(stepOneResult)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1)
        XCTAssertFalse(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in },
            "The checkout is still active in the approval sheet; nothing was re-queued"
        )

        // The genuine cancel re-queues the checkout so the confirm button can start it again.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertNil(stepOneResult, "Cancel defers the Step-1 completion")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
    }

    // MARK: - A cancel after a lifecycle fence drops the checkout instead of re-queueing it

    func test_handleURLCallback_payPalCancel_afterItsLayoutClosedWhilePresented_dropsTheCheckout() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout(cancelURL: "myapp://paypal/cancel") { stepOneResult = $0 }

        // The placement closes while the approval sheet is up; its entry is out of the pending table at this point.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=ORDER_MOCK")!))
        drainMainQueue()

        XCTAssertNil(stepOneResult, "Nothing is owed for a placement that is gone")
        XCTAssertFalse(
            sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()),
            "A cancel must not re-queue a checkout for a placement that closed while the sheet was up"
        )
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
    }

    func test_handleURLCallback_payPalCancel_afterTheSessionClearedWhilePresented_dropsTheCheckout() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout(cancelURL: "myapp://paypal/cancel") { stepOneResult = $0 }

        sut.discardAllPendingBuiltInTwoStep()

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=ORDER_MOCK")!))
        drainMainQueue()

        XCTAssertNil(stepOneResult)
        XCTAssertFalse(
            sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()),
            "A cancel must not re-queue a checkout for a session that was cleared while the sheet was up"
        )
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
    }

    func test_handleURLCallback_payPalCancel_withoutAFenceOnItsLayout_requeuesTheCheckout() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout(cancelURL: "myapp://paypal/cancel") { stepOneResult = $0 }

        // Another layout under the same execute closes while the sheet is up; this checkout's layout stays open.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "other_layout")

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=ORDER_MOCK")!))
        drainMainQueue()

        XCTAssertNil(stepOneResult, "Cancel defers the Step-1 completion")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The confirm button can start the checkout again")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
    }

    func test_processPayment_payPal_failsWhenOrderIdMissing() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse(orderId: "  ")

        let failed = expectation(description: "PayPal fails without an order id")
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in
                XCTFail("Confirmation must not be shown without an order id")
            }
        ) { result in
            XCTAssertEqual(result.outcome, .failed)
            XCTAssertEqual(result.errorMessage, PaymentOrchestrator.payPalOrderIdMissingMessage)
            failed.fulfill()
        }
        wait(for: [failed], timeout: 1.0)

        XCTAssertEqual(payPalPresenter.presentCallCount, 0)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1)
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsCallStack, PaymentOrchestrator.payPalOrderIdMissingMessage)
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
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

    // MARK: - cart wire-value helpers

    func test_cartPaymentMethodTypeWireValue_returnsPascalCaseMemberNamesForAllMethods() {
        // PascalCase cart-api `PaymentMethodType` member names — the same vocabulary DCUI
        // returns in `paymentProvider`, accepted by cart-api (Newtonsoft matches member names
        // case-insensitively). Note `.applePay` is `"ApplePay"`, NOT the `TransactionData.type`
        // token `"APPLE_PAY"`, which would not deserialize into the cart-api enum.
        XCTAssertEqual(PaymentOrchestrator.cartPaymentMethodTypeWireValue(for: .applePay), "ApplePay")
        XCTAssertEqual(PaymentOrchestrator.cartPaymentMethodTypeWireValue(for: .card), "Card")
        XCTAssertEqual(PaymentOrchestrator.cartPaymentMethodTypeWireValue(for: .paypal), "Paypal")
        // Cart wire (`Afterpay`) intentionally diverges from `PaymentMethodType.wireValue`
        // (`afterpay_clearpay`, used for extension matching).
        XCTAssertEqual(PaymentOrchestrator.cartPaymentMethodTypeWireValue(for: .afterpay), "Afterpay")
        XCTAssertEqual(PaymentMethodType.afterpay.wireValue, "afterpay_clearpay")
    }

    func test_cartPaymentProviderWireValue_returnsPascalCaseTokensForAllMethods() {
        // PascalCase pass-through of the DcuiSchema PaymentProvider enum — matches the web
        // SDK payload on INITIATE_DEVICE_PAY_EVENT.
        XCTAssertEqual(PaymentOrchestrator.cartPaymentProviderWireValue(for: .applePay), "ApplePay")
        XCTAssertEqual(PaymentOrchestrator.cartPaymentProviderWireValue(for: .card), "Card")
        XCTAssertEqual(PaymentOrchestrator.cartPaymentProviderWireValue(for: .paypal), "PayPal")
        XCTAssertEqual(PaymentOrchestrator.cartPaymentProviderWireValue(for: .afterpay), "Afterpay")
    }

    // MARK: - paymentMethod / paymentProvider plumbing for extension flows

    func test_processPayment_extensionFlow_forwardsPaymentProviderToInitializePurchase() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let item = PaymentItem(id: "item1", name: "Widget", amount: 10, currency: "USD")
        sut.processPayment(
            method: .applePay,
            paymentProvider: "Stripe",
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-stripe:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called in this test")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment completes")
        let address = ContactAddress(name: "Jane Doe", email: "jane@example.com")
        preparePayment(address) { _, _ in expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "ApplePay")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "Stripe")
    }

    func test_processPayment_extensionFlow_cardMethod_passesCardWireValueAsPaymentMethod() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.card])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let item = PaymentItem(id: "item1", name: "Widget", amount: 10, currency: "USD")
        // No builtInCardDevicePaySession -> routes via the registered extension, not built-in card.
        sut.processPayment(
            method: .card,
            paymentProvider: "Stripe",
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-stripe-card:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called in this test")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment completes")
        let address = ContactAddress(name: "Jane Doe", email: "jane@example.com")
        preparePayment(address) { _, _ in expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Card")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "Stripe")
    }

    func test_processPayment_extensionFlow_afterpay_passesAfterpayWireValueNotClearpay() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.afterpay])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let item = PaymentItem(id: "item1", name: "Widget", amount: 10, currency: "USD")
        sut.processPayment(
            method: .afterpay,
            paymentProvider: "Afterpay",
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-afterpay:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called in this test")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment completes")
        let address = ContactAddress(name: "Jane Doe", email: "jane@example.com")
        preparePayment(address) { _, _ in expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        // Cart wire is "Afterpay" (cart-api member name), not the extension-matching "afterpay_clearpay".
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Afterpay")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "Afterpay")
    }

    func test_processPayment_extensionFlow_emptyPaymentProvider_passesNilToInitializePurchase() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)

        let ext = MockPaymentExtension(id: "ext1", supportedMethods: [.applePay])
        ext.shouldAutomaticallyCompletePayment = false
        sut.register(ext, config: [:])
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let item = PaymentItem(id: "item1", name: "Widget", amount: 10, currency: "USD")
        sut.processPayment(
            method: .applePay,
            paymentProvider: "   ",
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-empty-provider:canal",
            from: UIViewController()
        ) { _ in
            XCTFail("Completion should not be called in this test")
        }

        guard let preparePayment = ext.capturedPreparePayment else {
            XCTFail("Expected preparePayment callback to be captured")
            return
        }

        let expectation = expectation(description: "preparePayment completes")
        let address = ContactAddress(name: "Jane Doe", email: "jane@example.com")
        preparePayment(address) { _, _ in expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "ApplePay")
        XCTAssertNil(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider)
    }

    func test_processPayment_builtInPayPal_ignoresCallerSuppliedPaymentProvider() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        let context = PaymentContext(returnURL: "myapp://paypal/success", cancelURL: "myapp://paypal/cancel")
        let item = PaymentItem(id: "item-paypal", name: "Widget", amount: 9.99, currency: "USD")
        sut.processPayment(
            method: .paypal,
            paymentProvider: "Stripe", // garbage value — built-in PayPal must override.
            item: item,
            context: context,
            cartItemId: "v1:cart-paypal-override:canal",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { _ in }

        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Paypal")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "PayPal")
    }

    func test_processPayment_builtInCard_ignoresCallerSuppliedPaymentProvider() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()

        let confirmationExpectation = expectation(description: "Card showConfirmation fires")
        let cardSession = BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: "test_layout",
            catalogItemId: "test_catalog"
        ) { _, _, _ in
            confirmationExpectation.fulfill()
        }

        let item = PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD")
        sut.processPayment(
            method: .card,
            paymentProvider: "Stripe", // garbage value — built-in card must override.
            item: item,
            context: PaymentContext(),
            cartItemId: "v1:cart-card-override:canal",
            from: UIViewController(),
            builtInCardDevicePaySession: cardSession
        ) { _ in
            XCTFail("Step-1 completion fired before Step-2 popped it")
        }

        wait(for: [confirmationExpectation], timeout: 1.0)

        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentMethodType, "Card")
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastInitializePurchasePaymentProvider, "Card")
    }
}

class PaymentOrchestratorAPIHelperSpy: RoktAPIHelper {
    static var initializePurchaseResponse: InitializePurchaseResponse?
    static var initializePurchaseCallCount = 0
    static var lastInitializePurchaseReturnURL: String?
    static var lastInitializePurchaseCancelURL: String?
    static var lastInitializePurchasePaymentMethodType: String?
    static var lastInitializePurchasePaymentProvider: String?
    static var lastInitializePurchaseShippingAttributes: ShippingAttributes?
    static var sendDiagnosticsCallCount = 0
    static var lastDiagnosticsMessage: String?
    static var lastDiagnosticsCallStack: String?
    static var lastDiagnosticsSeverity: Severity?
    static var lastDiagnosticsAdditionalInfo: [String: Any]?

    static func reset() {
        initializePurchaseResponse = nil
        initializePurchaseCallCount = 0
        lastInitializePurchaseReturnURL = nil
        lastInitializePurchaseCancelURL = nil
        lastInitializePurchasePaymentMethodType = nil
        lastInitializePurchasePaymentProvider = nil
        lastInitializePurchaseShippingAttributes = nil
        sendDiagnosticsCallCount = 0
        lastDiagnosticsMessage = nil
        lastDiagnosticsCallStack = nil
        lastDiagnosticsSeverity = nil
        lastDiagnosticsAdditionalInfo = nil
    }

    override class func initializePurchase(
        upsellItems: [UpsellItem],
        shippingAttributes: ShippingAttributes,
        returnURL: String? = nil,
        cancelURL: String? = nil,
        paymentMethodType: String? = nil,
        paymentProvider: String? = nil,
        success: ((InitializePurchaseResponse) -> Void)?,
        failure: ((Error, Int?, String) -> Void)?
    ) {
        initializePurchaseCallCount += 1
        lastInitializePurchaseReturnURL = returnURL
        lastInitializePurchaseCancelURL = cancelURL
        lastInitializePurchasePaymentMethodType = paymentMethodType
        lastInitializePurchasePaymentProvider = paymentProvider
        lastInitializePurchaseShippingAttributes = shippingAttributes
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
        lastDiagnosticsSeverity = severity
        lastDiagnosticsAdditionalInfo = additionalInfo
        success?()
    }
}
