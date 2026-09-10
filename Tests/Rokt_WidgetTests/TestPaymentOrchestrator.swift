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
    /// The completion of the last sheet presented, for a test that reports back after acting while the sheet is up.
    private(set) var capturedCompletion: ((PaymentSheetResult) -> Void)?
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
        capturedCompletion = completion
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
/// Hands each checkout a stand-in sheet that reads as on screen until the checkout dismisses it or the test tears it
/// down, the way the web presenter hands over the Safari sheet it presented.
final class HoldingPayPalApprovalPresenter: PayPalApprovalPresenting {
    private(set) var presentCallCount = 0
    private(set) var presentedSheets: [PayPalApprovalSheetStandIn] = []

    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    ) {
        presentCallCount += 1
        _ = approvalURL
        _ = viewController
        let sheet = PayPalApprovalSheetStandIn.onScreen()
        presentedSheets.append(sheet)
        checkoutCoordinator.attachPresentingCheckoutViewController(sheet)
    }
}

/// Stands in for a presented approval sheet: its view sits in a window until the checkout dismisses it, or until the
/// test tears it down the way a host replacing the screen would, without a cancel or a return ever reporting back.
/// `cover()` puts another full-screen view over it the way UIKit does: the sheet's own view leaves its window while the
/// covering controller, reported through `presentedViewController`, has its view in one; `uncover()` reverses that.
final class PayPalApprovalSheetStandIn: UIViewController {
    private let window = UIWindow()
    private let coverWindow = UIWindow()
    private var coveringViewController: UIViewController?

    static func onScreen() -> PayPalApprovalSheetStandIn {
        let sheet = PayPalApprovalSheetStandIn()
        sheet.window.addSubview(sheet.view)
        return sheet
    }

    override var presentedViewController: UIViewController? { coveringViewController }

    /// Takes the sheet off screen without reporting back.
    func tearDown() {
        view.removeFromSuperview()
    }

    /// Presents a full-screen view over the sheet: the sheet's own view leaves its window and the cover's takes one.
    func cover() {
        view.removeFromSuperview()
        let cover = UIViewController()
        coverWindow.addSubview(cover.view)
        coveringViewController = cover
    }

    /// Ends the covering presentation: the cover's view leaves its window and the sheet's own view returns to its.
    func uncover() {
        coveringViewController?.view.removeFromSuperview()
        coveringViewController = nil
        window.addSubview(view)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        _ = flag
        tearDown()
        completion?()
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

/// Like ``HoldingPayPalApprovalPresenter``, but its sheets dismiss the way a presented one does: the sheet stays in its
/// window while it animates away, and the dismissal's completion runs a main-queue turn after it is asked for, as it
/// would after the dismissal animation, so a checkout's callback lands after work queued in between.
final class AnimatedDismissPayPalApprovalPresenter: PayPalApprovalPresenting {
    private(set) var presentCallCount = 0
    private(set) var presentedSheets: [AnimatedDismissApprovalSheetStandIn] = []

    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    ) {
        presentCallCount += 1
        _ = approvalURL
        _ = viewController
        let sheet = AnimatedDismissApprovalSheetStandIn.onScreen()
        presentedSheets.append(sheet)
        checkoutCoordinator.attachPresentingCheckoutViewController(sheet)
    }
}

/// Stands in for a presented approval sheet whose dismissal animates: its view stays in the window until the
/// dismissal completes, one main-queue turn later, and leaves it in the same turn that runs the completion, the order
/// UIKit keeps.
final class AnimatedDismissApprovalSheetStandIn: UIViewController {
    private let window = UIWindow()

    static func onScreen() -> AnimatedDismissApprovalSheetStandIn {
        let sheet = AnimatedDismissApprovalSheetStandIn()
        sheet.window.addSubview(sheet.view)
        return sheet
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        _ = flag
        DispatchQueue.main.async {
            self.view.removeFromSuperview()
            completion?()
        }
    }
}

/// Like ``HoldingPayPalApprovalPresenter``, but keeps a strong reference to every checkout it was handed, the way a
/// presenter that stores its coordinator would, so a checkout whose sheet the host tore down stays alive to report
/// back late.
final class RetainingPayPalApprovalPresenter: PayPalApprovalPresenting {
    private(set) var presentedSheets: [PayPalApprovalSheetStandIn] = []
    private(set) var presentedCheckouts: [PayPalCheckoutCoordinator] = []

    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    ) {
        _ = approvalURL
        _ = viewController
        let sheet = PayPalApprovalSheetStandIn.onScreen()
        presentedSheets.append(sheet)
        presentedCheckouts.append(checkoutCoordinator)
        checkoutCoordinator.attachPresentingCheckoutViewController(sheet)
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
        layoutId: String = "test_layout",
        onConfirmation: ((String, String, [String: String]) -> Void)? = nil
    ) -> BuiltInTwoStepDevicePaySession {
        BuiltInTwoStepDevicePaySession(
            executeId: Self.testExecuteId,
            layoutId: layoutId,
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

    // MARK: - A Step-1 response that lands after its placement or session went away shows and stores nothing

    /// Starts built-in PayPal Step-1 with the response held back, so the test can close a layout or clear the
    /// session while the request is still out, then deliver the response with `releaseHeldInitializePurchase()`.
    private func startHeldPayPalStepOne(
        response: InitializePurchaseResponse? = TestPaymentOrchestrator.validPayPalInitializePurchaseResponse(),
        returnURL: String? = "myapp://paypal/success",
        onConfirmation: @escaping () -> Void,
        onStepOneResult: @escaping (PaymentSheetResult) -> Void
    ) {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = response
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: returnURL,
                cancelURL: nil
            ),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in onConfirmation() },
            completion: onStepOneResult
        )
        XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.initializePurchaseCallCount, 1)
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "Nothing is stored before the response")
    }

    func test_stepOne_payPal_responseAfterItsLayoutClosed_showsNoConfirmationAndStoresNothing() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalStepOne(
            onConfirmation: { XCTFail("No confirm button is shown for a placement that closed while the request was out") },
            onStepOneResult: { stepOneResult = $0 }
        )

        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        drainMainQueue()

        XCTAssertNil(stepOneResult, "Nothing is owed for a placement that is gone")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
    }

    func test_stepOne_payPal_failureAfterItsLayoutClosed_reportsNothing() {
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalStepOne(
            response: nil,
            onConfirmation: { XCTFail("A failed Step-1 never shows a confirm button") },
            onStepOneResult: { stepOneResult = $0 }
        )

        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        drainMainQueue()

        XCTAssertNil(stepOneResult, "No failure is reported for a placement that is gone")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
    }

    func test_stepOne_payPal_responseAfterAnotherLayoutClosed_showsConfirmationWithTheCheckoutAlreadyStored() {
        var confirmationCount = 0
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalStepOne(
            onConfirmation: {
                confirmationCount += 1
                XCTAssertTrue(
                    self.sut.unitTest_hasPendingBuiltInTwoStep(for: self.testKey()),
                    "The checkout is stored before the confirm button appears, so a confirm can never miss it"
                )
            },
            onStepOneResult: { stepOneResult = $0 }
        )

        // Another layout under the same execute closes while the request is out; this checkout's layout stays open.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "other_layout")
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        drainMainQueue()

        XCTAssertEqual(confirmationCount, 1)
        XCTAssertNil(stepOneResult, "The Step-1 completion waits for Step-2")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
    }

    func test_stepOne_payPal_supersededResponseWithoutAReturnURL_leavesTheNewerCheckoutInPlace() {
        var firstResult: PaymentSheetResult?
        startHeldPayPalStepOne(
            returnURL: nil,
            onConfirmation: { XCTFail("A Step-1 that was started again before it answered shows nothing") },
            onStepOneResult: { firstResult = $0 }
        )

        // Step-1 is started again for the same item and answers first, so its checkout is the one on offer.
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = false
        var confirmationCount = 0
        var secondResult: PaymentSheetResult?
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
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in confirmationCount += 1 },
            completion: { secondResult = $0 }
        )
        XCTAssertEqual(confirmationCount, 1)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        // The earlier request answers without a return URL; that answer belongs to nobody now.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        drainMainQueue()

        XCTAssertNil(firstResult, "The superseded Step-1 reports nothing")
        XCTAssertNil(secondResult, "The newer Step-1 completion waits for Step-2")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The newer checkout stays on offer")
        XCTAssertEqual(confirmationCount, 1)
    }

    func test_stepOne_payPal_replacementThatFails_dropsTheEarlierCheckoutForTheItem() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        var confirmationCount = 0
        func startStepOne(completion: @escaping (PaymentSheetResult) -> Void) {
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
                builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in confirmationCount += 1 },
                completion: completion
            )
        }
        var firstResult: PaymentSheetResult?
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()
        startStepOne { firstResult = $0 }
        XCTAssertEqual(confirmationCount, 1)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        // Step-1 runs again for the same item and fails, so the layout is told this attempt failed.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = nil
        var secondResult: PaymentSheetResult?
        startStepOne { secondResult = $0 }
        drainMainQueue()

        XCTAssertEqual(secondResult?.outcome, .failed)
        XCTAssertEqual(confirmationCount, 1, "A failed Step-1 never shows a confirm button")
        XCTAssertNil(firstResult, "The earlier checkout is dropped without a report, like any other discarded one")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "Nothing is left for a later confirm to start")
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 0, "The superseded order's approval sheet is never presented")
    }

    func test_stepOne_payPal_confirmWhileAReplacementIsOut_doesNotPresentTheSupersededOrder() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        // Held strongly until the deferred present has run; the pending checkout only keeps a weak reference.
        let presentingViewController = UIViewController()
        var confirmationCount = 0
        func startStepOne(orderId: String, completion: @escaping (PaymentSheetResult) -> Void) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
                Self.validPayPalInitializePurchaseResponse(orderId: orderId)
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
                builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in confirmationCount += 1 },
                completion: completion
            )
        }
        var firstResult: PaymentSheetResult?
        startStepOne(orderId: "ORDER_1") { firstResult = $0 }
        XCTAssertEqual(confirmationCount, 1)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        // Step-1 runs again for the same item; its response is still out when the confirm arrives.
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        var secondResult: PaymentSheetResult?
        startStepOne(orderId: "ORDER_2") { secondResult = $0 }
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The superseded checkout is off offer at once")
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in
                XCTFail("Nothing is presented while the new request is out")
            },
            "The confirm stays on the PayPal path instead of running a card purchase"
        )
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 0, "The superseded order's approval sheet is never presented")

        // The new request answers: it is the one checkout on offer, and the confirm button is shown again for it.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertEqual(confirmationCount, 2)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)

        // A return link for the superseded order is claimed but completes nothing; the new order's completes the checkout.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_1")!))
        drainMainQueue()
        XCTAssertEqual(
            PaymentOrchestratorAPIHelperSpy.lastDiagnosticsCallStack,
            PaymentOrchestrator.payPalReturnLinkOrderMismatchMessage
        )
        XCTAssertNil(firstResult, "The superseded checkout is dropped without a report, like any other discarded one")
        XCTAssertNil(secondResult)
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(secondResult?.outcome, .succeeded)
        XCTAssertEqual(secondResult?.transactionId, "ORDER_2")
        XCTAssertNil(firstResult)
    }

    /// A card Step-1 replaces an item's PayPal checkout. Until it answers, a confirm for the item is held: it neither
    /// presents the superseded order nor falls through to a cart purchase with no card checkout behind it. Once it has
    /// answered, exactly one card checkout is stored and the next confirm starts its purchase.
    func test_stepOne_card_confirmWhileItReplacesThePayPalCheckout_startsNoPurchaseAndStoresOneCardCheckout() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        // Held strongly: the pending PayPal checkout only keeps a weak reference to the screen it presents from.
        let presentingViewController = UIViewController()
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_1")
        var payPalResult: PaymentSheetResult?
        var payPalConfirmationCount = 0
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
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in payPalConfirmationCount += 1 }
        ) { payPalResult = $0 }
        XCTAssertEqual(payPalConfirmationCount, 1)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        // Card Step-1 starts for the same item; its response is still out when the confirm arrives.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        var cardResult: PaymentSheetResult?
        var cardConfirmationCount = 0
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "test_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in cardConfirmationCount += 1 }
        ) { cardResult = $0 }
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The PayPal checkout is off offer at once")
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in
                XCTFail("Nothing is presented while the card request is out")
            },
            "The confirm is held instead of falling through to a cart purchase for the item"
        )
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "No card checkout is stored yet")
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 0, "The superseded order's approval sheet is never presented")
        XCTAssertNil(payPalResult, "The superseded checkout is dropped without a report, like any other discarded one")
        XCTAssertNil(cardResult)

        // The card request answers: it is the one checkout on offer, and the next confirm starts its purchase.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertEqual(cardConfirmationCount, 1, "The confirm button is shown again, for the card checkout")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertFalse(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in },
            "With the card checkout stored, the confirm falls through to its cart purchase"
        )
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "One card checkout is stored for the item")
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "It was the only one, and is now in flight")
        XCTAssertNil(payPalResult)
        XCTAssertNil(cardResult, "The card checkout reports once its purchase has an outcome")
    }

    /// A PayPal Step-1 replaces an item's prepared card checkout. Until it answers, a confirm for the item is held: it
    /// neither sends the card purchase the request supersedes nor presents anything. Once it has answered, exactly one
    /// PayPal checkout is stored and the next confirm presents its approval sheet; the card checkout never reports.
    func test_stepOne_payPal_confirmWhileItReplacesTheCardCheckout_startsNoPurchaseAndStoresOnePayPalCheckout() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        // Held strongly: the pending PayPal checkout only keeps a weak reference to the screen it presents from.
        let presentingViewController = UIViewController()
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
        var cardResult: PaymentSheetResult?
        var cardConfirmationCount = 0
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "test_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in cardConfirmationCount += 1 }
        ) { cardResult = $0 }
        XCTAssertEqual(cardConfirmationCount, 1)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        // PayPal Step-1 starts for the same item; its response is still out when the confirm arrives.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        var payPalResult: PaymentSheetResult?
        var payPalConfirmationCount = 0
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
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in payPalConfirmationCount += 1 }
        ) { payPalResult = $0 }
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The prepared card checkout is off offer at once")
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in
                XCTFail("Nothing is presented while the PayPal request is out")
            },
            "The confirm is held instead of falling through to a cart purchase for the item"
        )
        XCTAssertNil(
            sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()),
            "No card purchase is sent for the superseded checkout"
        )
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 0)
        XCTAssertNil(cardResult, "The superseded checkout is dropped without a report, like any other discarded one")
        XCTAssertNil(payPalResult)

        // The PayPal request answers: it is the one checkout on offer, and the next confirm presents its approval sheet.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertEqual(payPalConfirmationCount, 1, "The confirm button is shown again, for the PayPal checkout")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "No card checkout is stored for the item")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)

        // The new order's return link completes the PayPal checkout; the card checkout still reports nothing.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(payPalResult?.outcome, .succeeded)
        XCTAssertEqual(payPalResult?.transactionId, "ORDER_2")
        XCTAssertNil(cardResult)
    }

    /// A card Step-1 starts again for an item whose card checkout is already prepared. Until it answers, a confirm for
    /// the item is held and sends no purchase for the superseded checkout; once it has answered, exactly one card
    /// checkout is stored and the next confirm starts its purchase. The superseded checkout never reports.
    func test_stepOne_card_confirmWhileItReplacesTheCardCheckout_startsNoPurchaseAndStoresOneCardCheckout() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        var confirmationCount = 0
        func startStepOne(completion: @escaping (PaymentSheetResult) -> Void) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
            sut.processPayment(
                method: .card,
                item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
                context: PaymentContext(),
                cartItemId: "v1:cart:1",
                from: UIViewController(),
                builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                    executeId: Self.testExecuteId,
                    layoutId: "test_layout",
                    catalogItemId: "test_catalog"
                ) { _, _, _ in confirmationCount += 1 },
                completion: completion
            )
        }
        var firstResult: PaymentSheetResult?
        startStepOne { firstResult = $0 }
        XCTAssertEqual(confirmationCount, 1)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        // Step-1 runs again for the same item; its response is still out when the confirm arrives.
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        var secondResult: PaymentSheetResult?
        startStepOne { secondResult = $0 }
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The superseded card checkout is off offer")
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in
                XCTFail("Nothing is presented while the new request is out")
            },
            "The confirm is held instead of falling through to a cart purchase for the item"
        )
        XCTAssertNil(
            sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()),
            "No purchase is sent for the superseded checkout"
        )
        drainMainQueue()
        XCTAssertNil(firstResult, "The superseded checkout is dropped without a report, like any other discarded one")
        XCTAssertNil(secondResult)

        // The new request answers: it is the one checkout on offer, and the next confirm starts its purchase.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertEqual(confirmationCount, 2, "The confirm button is shown again, for the new card checkout")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertFalse(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in },
            "With the card checkout stored, the confirm falls through to its cart purchase"
        )
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "One card checkout is stored for the item")
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "It was the only one, and is now in flight")
        XCTAssertNil(firstResult)
        XCTAssertNil(secondResult, "The new card checkout reports once its purchase has an outcome")
    }

    func test_stepOne_payPal_replacementThatSucceeds_whileItsApprovalSheetIsUp_keepsTheSheetAndReportsTheNewAttemptFailed() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        var firstResult: PaymentSheetResult?
        startHeldPayPalCheckout(presenter: payPalPresenter) { firstResult = $0 }
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)

        // Step-1 runs again for the same item while its approval sheet is up, and succeeds.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        var replacementResult: PaymentSheetResult?
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
                XCTFail("A replacement for an approval already on screen shows no confirm button")
            }
        ) { replacementResult = $0 }
        drainMainQueue()

        XCTAssertEqual(replacementResult?.outcome, .failed)
        XCTAssertEqual(replacementResult?.errorMessage, PaymentOrchestrator.builtInPayPalApprovalInProgressMessage)
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "No second checkout is stored for the item")
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)

        // The approval on screen still completes from its own return link, and nothing of the item is left.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertEqual(firstResult?.outcome, .succeeded)
        XCTAssertEqual(firstResult?.transactionId, "ORDER_MOCK")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 0)
    }

    func test_stepOne_card_whileTheItemsPayPalApprovalSheetIsUp_storesNothingAndReportsTheNewAttemptFailed() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        var firstResult: PaymentSheetResult?
        startHeldPayPalCheckout(presenter: payPalPresenter) { firstResult = $0 }

        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
        var replacementResult: PaymentSheetResult?
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "test_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in
                XCTFail("A replacement for an approval already on screen shows no confirm button")
            }
        ) { replacementResult = $0 }
        drainMainQueue()

        XCTAssertEqual(replacementResult?.outcome, .failed)
        XCTAssertEqual(replacementResult?.errorMessage, PaymentOrchestrator.builtInPayPalApprovalInProgressMessage)
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "No card checkout is stored for the item")

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertEqual(firstResult?.outcome, .succeeded)
    }

    func test_stepOne_card_replacementThatFails_keepsACardPurchaseAlreadyInFlight() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        let purchaseResultDelivered = expectation(description: "The purchase already sent still reaches its completion")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: testKey()) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            purchaseResultDelivered.fulfill()
        }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()))
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())

        // Step-1 runs again for the same item while its purchase is out, and fails.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = nil
        var replacementResult: PaymentSheetResult?
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "test_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in
                XCTFail("A failed Step-1 never shows a confirm button")
            }
        ) { replacementResult = $0 }
        drainMainQueue()

        XCTAssertEqual(replacementResult?.outcome, .failed)
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The purchase already sent keeps its entry")
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight(), "Its result can still reach its completion")

        sut.finishBuiltInCardForwardPaymentAttempt(for: testKey(), result: .succeeded(transactionId: "card_txn"))
        wait(for: [purchaseResultDelivered], timeout: 1.0)
    }

    func test_stepOne_card_replacementThatSucceeds_keepsACardPurchaseAlreadyInFlight() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        let purchaseResultDelivered = expectation(description: "The purchase already sent still reaches its completion")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: testKey()) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            purchaseResultDelivered.fulfill()
        }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()))
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())

        // Step-1 runs again for the same item while its purchase is out, and succeeds: the purchase already
        // sent keeps its place, no confirm button appears for the new attempt, and the new attempt is reported
        // as failed.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
        var replacementResult: PaymentSheetResult?
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "test_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in
                XCTFail("A replacement for a purchase already in flight shows no confirm button")
            }
        ) { replacementResult = $0 }
        drainMainQueue()

        XCTAssertEqual(replacementResult?.outcome, .failed)
        XCTAssertEqual(replacementResult?.errorMessage, PaymentOrchestrator.builtInCardPurchaseInFlightMessage)
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight(), "The purchase already sent keeps its entry")

        sut.finishBuiltInCardForwardPaymentAttempt(for: testKey(), result: .succeeded(transactionId: "card_txn"))
        wait(for: [purchaseResultDelivered], timeout: 1.0)
    }

    func test_stepOne_payPal_replacementThatSucceeds_keepsACardPurchaseAlreadyInFlight() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        let purchaseResultDelivered = expectation(description: "The purchase already sent still reaches its completion")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: testKey()) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            purchaseResultDelivered.fulfill()
        }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()))
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())

        // A PayPal Step-1 for the same item succeeds while the card purchase is out: the purchase keeps its place,
        // no confirm button appears, no PayPal checkout is stored, and the new attempt is reported as failed.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()
        var replacementResult: PaymentSheetResult?
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
                XCTFail("A replacement for a purchase already in flight shows no confirm button")
            }
        ) { replacementResult = $0 }
        drainMainQueue()

        XCTAssertEqual(replacementResult?.outcome, .failed)
        XCTAssertEqual(replacementResult?.errorMessage, PaymentOrchestrator.builtInCardPurchaseInFlightMessage)
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight(), "The purchase already sent keeps its entry")
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 0, "No PayPal checkout was stored for the new attempt")

        sut.finishBuiltInCardForwardPaymentAttempt(for: testKey(), result: .succeeded(transactionId: "card_txn"))
        wait(for: [purchaseResultDelivered], timeout: 1.0)
    }

    /// A card purchase fails retryably while a newer Step-1 for its item is out. The failed purchase is dropped rather
    /// than put back on offer, since the item's confirm button now belongs to the new request, whose response then
    /// stores the one card checkout on offer. Nothing is reported for the execute while that request is out.
    func test_restoreAfterRetryableFailure_dropsACardPurchaseWhoseItemHasANewerStepOneOut() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: testKey()) { _ in XCTFail("A dropped entry reports nothing") }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()))
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight())

        // Step-1 runs again for the item while its purchase is out; its response is held back.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        var confirmationCount = 0
        var replacementResult: PaymentSheetResult?
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "test_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in confirmationCount += 1 }
        ) { replacementResult = $0 }
        XCTAssertTrue(sut.isBuiltInCardForwardPaymentInFlight(), "The purchase already sent keeps its place")

        // The purchase fails retryably: its item's confirm button belongs to the new request, so it is dropped.
        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: testKey())
        drainMainQueue()
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The failed purchase is not put back on offer")
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "A confirm in the window sends nothing")
        XCTAssertTrue(
            sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId),
            "The request still out keeps the execute outstanding"
        )
        XCTAssertTrue(reported.isEmpty, "Not reported while the new request is out")

        // The new request answers: its card checkout is the one on offer.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertEqual(confirmationCount, 1, "The confirm button is shown for the new card checkout")
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "One card checkout is stored for the item")
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()), "It was the only one, and is now in flight")
        XCTAssertNil(replacementResult, "The new checkout reports once its purchase has an outcome")
        XCTAssertTrue(reported.isEmpty)
    }

    func test_stepOne_card_responseAfterTheSessionCleared_showsNoConfirmationAndStoresNothing() {
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self)
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validInitializePurchaseResponse()
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        var stepOneResult: PaymentSheetResult?
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:1",
            from: UIViewController(),
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "test_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in
                XCTFail("No confirm button is shown for a session that was cleared while the request was out")
            }
        ) { stepOneResult = $0 }
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "Nothing is stored before the response")

        sut.discardAllPendingBuiltInTwoStep()
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        drainMainQueue()

        XCTAssertNil(stepOneResult, "Nothing is owed for a session that is gone")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertNil(sut.beginBuiltInCardForwardPaymentIfReady(for: testKey()))
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

    func test_restoreAfterRetryableFailure_dropsACardPurchaseWhoseLayoutClosedWhileItWasInFlight() {
        let fencedKey = BuiltInTwoStepCheckoutKey(
            executeId: "execute_a", layoutId: "closed", catalogItemId: "c", cartItemId: "cart_a"
        )
        let openKey = BuiltInTwoStepCheckoutKey(
            executeId: "execute_a", layoutId: "open", catalogItemId: "c", cartItemId: "cart_b"
        )
        for key in [fencedKey, openKey] {
            sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: key) { _ in
                XCTFail("A retryable failure invokes no Step-1 completion")
            }
            XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: key))
        }

        sut.discardPendingBuiltInTwoStep(forExecuteId: "execute_a", layoutId: "closed")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: fencedKey), "The purchase already sent is kept")

        // The purchase then fails in a retryable way: the closed layout's entry is dropped, not restored to a
        // confirm state nothing can resume; the open layout's entry is restored as before.
        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: fencedKey)
        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: openKey)
        drainMainQueue()

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: fencedKey))
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: openKey))
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: openKey), "The open layout can confirm again")
    }

    func test_restoreAfterRetryableFailure_dropsACardPurchaseWhoseSessionClearedWhileItWasInFlight() {
        let key = BuiltInTwoStepCheckoutKey(executeId: "execute_a", layoutId: "l", catalogItemId: "c", cartItemId: "cart_a")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: key) { _ in
            XCTFail("A retryable failure invokes no Step-1 completion")
        }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: key))

        sut.discardAllPendingBuiltInTwoStep()
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: key), "The purchase already sent is kept")

        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: key)
        drainMainQueue()

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: key))
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

    /// A cleartext approval URL is accepted only on a loopback host, where a local development backend serves it. On
    /// any other host it is rejected before the confirm button, and the diagnostic names the scheme, never the URL.
    func test_processPayment_payPal_failsWhenApprovalUrlIsCleartextOnNonLoopbackHost() {
        for approvalUrl in [
            "http://www.example.com/checkoutnow?token=ORDER",
            "http://localhost.example.com/approve",
            "http://192.168.1.10:9011/approve"
        ] {
            let result = runPayPalStepOneExpectingRejection(approvalUrl: approvalUrl)

            XCTAssertEqual(result?.outcome, .failed, approvalUrl)
            XCTAssertEqual(result?.errorMessage, PaymentOrchestrator.payPalApprovalURLInvalidMessage, approvalUrl)
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.sendDiagnosticsCallCount, 1, approvalUrl)
            XCTAssertEqual(
                PaymentOrchestratorAPIHelperSpy.lastDiagnosticsMessage,
                PaymentOrchestrator.devicePayErrorCode,
                approvalUrl
            )
            XCTAssertEqual(PaymentOrchestratorAPIHelperSpy.lastDiagnosticsSeverity, .warning, approvalUrl)
            let additionalInfo = PaymentOrchestratorAPIHelperSpy.lastDiagnosticsAdditionalInfo ?? [:]
            XCTAssertEqual(additionalInfo["scheme"] as? String, "http", approvalUrl)
            XCTAssertEqual(additionalInfo["hostPresent"] as? Bool, true, approvalUrl)
            let loggedStrings = additionalInfo.values.compactMap { $0 as? String }
            XCTAssertFalse(
                loggedStrings.contains { $0.contains(approvalUrl) },
                "Diagnostics must not carry the approval URL: \(approvalUrl)"
            )
        }
    }

    func test_processPayment_payPal_acceptsHttpApprovalUrlOnLoopbackHost() {
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
        presenter: HoldingPayPalApprovalPresenter = HoldingPayPalApprovalPresenter(),
        from presentingViewController: UIViewController = UIViewController(),
        onStepOneResult: @escaping (PaymentSheetResult) -> Void
    ) {
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: presenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()

        // The screen is held at least until the deferred present has run; the pending checkout only keeps a weak
        // reference. A test that presents the same order again after a cancel passes a screen it holds itself.
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
            sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()),
            "The checkout is still active in the approval sheet; nothing was re-queued"
        )
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in
                XCTFail("A repeated confirm while the sheet is up starts nothing")
            },
            "A repeated confirm stays on the PayPal path instead of running a card purchase"
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

    // MARK: - A cancel while a Step-1 started again for the item is out drops the cancelled order

    /// Step-1 runs again for an item while its PayPal approval sheet is up, and the buyer cancels before the new
    /// response lands. The cancelled order is dropped rather than put back on offer: a confirm in the window starts
    /// nothing, the new response is stored as the item's one checkout instead of being rejected as an approval already
    /// in progress, and the next confirm presents the new order. Nothing of the dropped order is reported.
    func test_handleURLCallback_payPalCancel_whileAStepOneStartedAgainForTheItemIsOut_dropsTheOldOrderAndStoresTheNew() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout(cancelURL: "myapp://paypal/cancel", presenter: payPalPresenter) { stepOneResult = $0 }
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        // Held strongly: the new pending checkout only keeps a weak reference to the screen it presents from.
        let presentingViewController = UIViewController()

        // Step-1 runs again for the item while its approval sheet is up; its response is held back.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        var confirmationCount = 0
        var secondResult: PaymentSheetResult?
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: "myapp://paypal/cancel"
            ),
            cartItemId: "v1:cart:1",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in confirmationCount += 1 }
        ) { secondResult = $0 }
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "The first order's sheet is still up")

        // The buyer cancels before the new response: the cancelled order is dropped, and the request out keeps the execute.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The cancelled order is not put back on offer")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 0)
        XCTAssertNil(stepOneResult, "Nothing of the dropped order is reported; the new request's outcome reports for the item")
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId), "The request is still out")
        XCTAssertTrue(reported.isEmpty, "No execute is reported as having nothing outstanding while the new request is out")

        // A confirm in the window starts nothing.
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in
                XCTFail("Nothing is presented while the new request is out")
            },
            "The confirm stays on the PayPal path with nothing to start"
        )
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "The cancelled order is never presented again")

        // The new response is stored, not rejected as an approval already in progress, and the next confirm presents it.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertEqual(confirmationCount, 1, "The confirm button is shown for the new checkout")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertNil(secondResult, "The new attempt is not reported as failed")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The new order's approval sheet is presented")

        // A return link for the dropped order completes nothing; the new order's completes the checkout.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertEqual(
            PaymentOrchestratorAPIHelperSpy.lastDiagnosticsCallStack,
            PaymentOrchestrator.payPalReturnLinkOrderMismatchMessage
        )
        XCTAssertNil(secondResult)
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(secondResult?.outcome, .succeeded)
        XCTAssertEqual(secondResult?.transactionId, "ORDER_2")
        XCTAssertNil(stepOneResult)
        XCTAssertTrue(reported.isEmpty)
    }

    /// Step-1 runs again for an item while its PayPal approval sheet is up and answers at once: the approval on screen
    /// keeps its place and the new attempt is reported as failed. When the buyer then cancels, the order on screen is
    /// the right one to keep on offer, and it comes back for the confirm button to start again.
    func test_stepOne_payPal_replacementRejectedWhileTheSheetIsUp_thenCancel_putsTheOrderOnScreenBackOnOffer() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        // Held strongly for the whole test: the re-queued order presents from it again after the cancel.
        let presentingViewController = UIViewController()
        var stepOneResult: PaymentSheetResult?
        startHeldPayPalCheckout(cancelURL: "myapp://paypal/cancel", presenter: payPalPresenter, from: presentingViewController) {
            stepOneResult = $0
        }

        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        var replacementResult: PaymentSheetResult?
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p1", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: "myapp://paypal/cancel"
            ),
            cartItemId: "v1:cart:1",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests { _, _, _ in
                XCTFail("A replacement for an approval already on screen shows no confirm button")
            }
        ) { replacementResult = $0 }
        drainMainQueue()
        XCTAssertEqual(replacementResult?.outcome, .failed)
        XCTAssertEqual(replacementResult?.errorMessage, PaymentOrchestrator.builtInPayPalApprovalInProgressMessage)

        // The buyer cancels: no request is out for the item any more, so the order on screen is put back on offer.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()), "The order on screen is back on offer")
        XCTAssertNil(stepOneResult, "Cancel defers the Step-1 completion")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The same order's approval sheet is presented again")

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertEqual(stepOneResult?.outcome, .succeeded)
        XCTAssertEqual(stepOneResult?.transactionId, "ORDER_MOCK")
    }

    // MARK: - One PayPal approval at a time

    func test_presentPendingBuiltInPayPal_secondItemWhileASheetIsUp_waitsAndKeepsReturnLinksOnTheFirstOrder() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        var firstResult: PaymentSheetResult?
        var secondResult: PaymentSheetResult?
        func startStepOne(cartItemId: String, orderId: String, completion: @escaping (PaymentSheetResult) -> Void) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
                Self.validPayPalInitializePurchaseResponse(orderId: orderId)
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
                builtInPayPalDevicePaySession: paypalDeviceSessionForTests(),
                completion: completion
            )
        }
        startStepOne(cartItemId: "v1:cart:1", orderId: "ORDER_1") { firstResult = $0 }
        startStepOne(cartItemId: "v1:cart:2", orderId: "ORDER_2") { secondResult = $0 }
        let firstKey = testKey(cartItemId: "v1:cart:1")
        let secondKey = testKey(cartItemId: "v1:cart:2")

        // Both confirms arrive before the first presentation has run on the main queue.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: firstKey) { _ in })
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in
                XCTFail("The second item is not presented while the first sheet is up")
            },
            "The second confirm stays on the PayPal path instead of running a card purchase"
        )
        drainMainQueue()

        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "Only one approval sheet is presented")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: firstKey))
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey), "The second item waits for a later confirm")

        // The first order's return link still reaches the first order's checkout.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_1")!))
        drainMainQueue()
        XCTAssertEqual(firstResult?.outcome, .succeeded)
        XCTAssertEqual(firstResult?.transactionId, "ORDER_1")
        XCTAssertNil(secondResult)

        // With the first sheet gone, the second item's confirm presents its own order.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 2)
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(secondResult?.outcome, .succeeded)
        XCTAssertEqual(secondResult?.transactionId, "ORDER_2")
    }

    func test_presentPendingBuiltInPayPal_afterASheetForAClosedLayoutNeverReportedBack_aLaterItemStillPresents() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        var firstResult: PaymentSheetResult?
        startHeldPayPalCheckout(presenter: payPalPresenter) { firstResult = $0 }
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)

        // The placement closes while its sheet is up, and the host then tears the sheet down (for example by replacing
        // its root view controller), so the sheet never reports a cancel or a return.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        payPalPresenter.presentedSheets.last?.tearDown()

        // A later placement offers a PayPal item; its confirm must not be held back by a sheet that is gone.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        // Held strongly until the deferred present has run; the pending checkout only keeps a weak reference.
        let presentingViewController = UIViewController()
        var laterResult: PaymentSheetResult?
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p2", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:2",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests(layoutId: "other_layout")
        ) { laterResult = $0 }
        let laterKey = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId,
            layoutId: "other_layout",
            catalogItemId: "test_catalog",
            cartItemId: "v1:cart:2"
        )
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: laterKey) { _ in })
        drainMainQueue()

        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The later item's approval sheet is presented")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: laterKey), "The later item's checkout was started")
        XCTAssertNil(firstResult, "Nothing is owed for the placement that closed")
        XCTAssertEqual(
            sut.unitTest_presentedBuiltInPayPalCount(), 1,
            "The first item's fenced mark went when this presentation released its checkout"
        )

        // The later order's return link completes the later checkout.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(laterResult?.outcome, .succeeded)
        XCTAssertEqual(laterResult?.transactionId, "ORDER_2")

        // Nothing is left to start, and no mark is left behind: the first item's fenced mark went at the replacement,
        // the later item's with its return link.
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: laterKey) { _ in })
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 0, "No mark is left for an abandoned approval")
    }

    func test_presentPendingBuiltInPayPal_aSheetTheHostTookOffScreenWithoutReporting_holdsALaterItemOnlyUntilItIsGone() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        var firstResult: PaymentSheetResult?
        var secondResult: PaymentSheetResult?
        func startStepOne(cartItemId: String, orderId: String, completion: @escaping (PaymentSheetResult) -> Void) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
                Self.validPayPalInitializePurchaseResponse(orderId: orderId)
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
                builtInPayPalDevicePaySession: paypalDeviceSessionForTests(),
                completion: completion
            )
        }
        startStepOne(cartItemId: "v1:cart:1", orderId: "ORDER_1") { firstResult = $0 }
        startStepOne(cartItemId: "v1:cart:2", orderId: "ORDER_2") { secondResult = $0 }
        let firstKey = testKey(cartItemId: "v1:cart:1")
        let secondKey = testKey(cartItemId: "v1:cart:2")

        // The first item's sheet is still being put up when the second confirm arrives: the presenter has not handed
        // it over yet, so there is no window to read, and the second item must still wait.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: firstKey) { _ in })
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in
                XCTFail("The second item is not presented while the first sheet is being put up")
            },
            "The second confirm stays on the PayPal path instead of running a card purchase"
        )
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "Only one approval sheet is presented")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey), "The second item waits for a later confirm")

        // The host takes the first sheet off screen (for example by dismissing every modal on a deep link) without a
        // cancel or a return ever reporting back, and without the layout closing: no lifecycle event fences the entry.
        payPalPresenter.presentedSheets.last?.tearDown()

        // The second item's confirm must not be held back by a sheet that is gone.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The second item's approval sheet is presented")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey), "The second item's checkout was started")
        XCTAssertNil(firstResult, "The first approval never reported back, so nothing is owed for it")
        XCTAssertEqual(
            sut.unitTest_presentedBuiltInPayPalCount(), 1,
            "The first item's mark went when this presentation released its checkout, though its layout never closed"
        )

        // The second order's return link completes the second checkout.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(secondResult?.outcome, .succeeded)
        XCTAssertEqual(secondResult?.transactionId, "ORDER_2")

        // Nothing is left to start, and no mark is left behind: the first item's mark went when the second presentation
        // released its checkout, and the second item's with its return link.
        XCTAssertFalse(sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in })
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 0, "No mark is left for an abandoned approval")
    }

    /// Another full-screen view presented over the first item's sheet takes the sheet's own view out of the window
    /// while the sheet stays presented and comes back the moment the cover goes. A confirm for a second item must wait
    /// for it as it waits for an uncovered sheet, and the first order's return link must keep reaching the first order.
    func test_presentPendingBuiltInPayPal_aCoveredSheet_holdsALaterItemAndKeepsReturnLinksOnTheFirstOrder() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        var firstResult: PaymentSheetResult?
        var secondResult: PaymentSheetResult?
        func startStepOne(cartItemId: String, orderId: String, completion: @escaping (PaymentSheetResult) -> Void) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
                Self.validPayPalInitializePurchaseResponse(orderId: orderId)
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
                builtInPayPalDevicePaySession: paypalDeviceSessionForTests(),
                completion: completion
            )
        }
        startStepOne(cartItemId: "v1:cart:1", orderId: "ORDER_1") { firstResult = $0 }
        startStepOne(cartItemId: "v1:cart:2", orderId: "ORDER_2") { secondResult = $0 }
        let firstKey = testKey(cartItemId: "v1:cart:1")
        let secondKey = testKey(cartItemId: "v1:cart:2")

        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: firstKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "The first item's approval sheet is presented")

        // Another full-screen view goes up over the first sheet: the sheet's own view leaves the window, the cover's is
        // in one, and nothing reports back because the sheet is still presented underneath.
        payPalPresenter.presentedSheets.last?.cover()

        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in
                XCTFail("The second item is not presented while the first sheet is covered")
            },
            "The second confirm stays on the PayPal path instead of running a card purchase"
        )
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "A covered sheet is still up, so nothing else is presented")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey), "The second item keeps waiting")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "The first item's mark is kept, not pruned")

        // The cover is dismissed: the first sheet is back on screen and still holds the second item back.
        payPalPresenter.presentedSheets.last?.uncover()
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in
                XCTFail("The second item is not presented while the first sheet is up")
            }
        )
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "The uncovered sheet still holds the second item back")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey))

        // The first order's return link still reaches the first order's checkout: its routing was never replaced.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_1")!))
        drainMainQueue()
        XCTAssertEqual(firstResult?.outcome, .succeeded)
        XCTAssertEqual(firstResult?.transactionId, "ORDER_1")
        XCTAssertNil(secondResult)

        // With the first sheet gone, the second item's confirm presents its own order.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The second item's approval sheet is presented")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey))
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(secondResult?.outcome, .succeeded)
        XCTAssertEqual(secondResult?.transactionId, "ORDER_2")
    }

    func test_presentPendingBuiltInPayPal_afterItsLayoutClosedWhileItsSheetIsStillUp_aLaterItemWaitsUntilThatSheetEnds() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        var firstResult: PaymentSheetResult?
        startHeldPayPalCheckout(presenter: payPalPresenter) { firstResult = $0 }
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)

        // The placement closes while its sheet is up. The sheet is not interrupted and stays on screen.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")

        // A later placement offers a PayPal item; its confirm must wait, or its sheet would cover the one still up and
        // take the return-link routing away from the first order.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        // Held strongly until the deferred present has run; the pending checkout only keeps a weak reference.
        let presentingViewController = UIViewController()
        var laterResult: PaymentSheetResult?
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p2", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:2",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests(layoutId: "other_layout")
        ) { laterResult = $0 }
        let laterKey = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId,
            layoutId: "other_layout",
            catalogItemId: "test_catalog",
            cartItemId: "v1:cart:2"
        )
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: laterKey) { _ in },
            "The later confirm stays on the PayPal path instead of running a card purchase"
        )
        drainMainQueue()

        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "No second sheet is presented over the one still up")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: laterKey), "The later item waits for a later confirm")
        XCTAssertNil(firstResult)

        // The first order's return link still reaches the first order's checkout, which ends its sheet.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertEqual(firstResult?.outcome, .succeeded)
        XCTAssertEqual(firstResult?.transactionId, "ORDER_MOCK")
        XCTAssertNil(laterResult)

        // With the first sheet gone, the later item's confirm presents its own order.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: laterKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The later item's approval sheet is presented")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: laterKey))
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(laterResult?.outcome, .succeeded)
        XCTAssertEqual(laterResult?.transactionId, "ORDER_2")
    }

    // MARK: - A checkout's completion undoes only its own presentation

    /// Two items of one placement. The first order is approved; its checkout is finished from that moment, but its
    /// sheet is still animating away and its callback waits for the dismissal to complete. A confirm for the second
    /// item in that gap must wait rather than present over the dismissing sheet (the screen would refuse the second
    /// sheet and the second checkout would fail), and the next confirm presents it once the first sheet is gone.
    func test_presentPendingBuiltInPayPal_aSecondItemsConfirmWhileTheFirstSheetIsStillDismissing_waitsUntilItIsGone() {
        let payPalPresenter = AnimatedDismissPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        var firstResult: PaymentSheetResult?
        var secondResult: PaymentSheetResult?
        func startStepOne(cartItemId: String, orderId: String, completion: @escaping (PaymentSheetResult) -> Void) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
                Self.validPayPalInitializePurchaseResponse(orderId: orderId)
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
                builtInPayPalDevicePaySession: paypalDeviceSessionForTests(),
                completion: completion
            )
        }
        startStepOne(cartItemId: "v1:cart:1", orderId: "ORDER_1") { firstResult = $0 }
        startStepOne(cartItemId: "v1:cart:2", orderId: "ORDER_2") { secondResult = $0 }
        let firstKey = testKey(cartItemId: "v1:cart:1")
        let secondKey = testKey(cartItemId: "v1:cart:2")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: firstKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)

        // The buyer approves the first order. Its checkout is finished from this moment, but its sheet is still up and
        // its callback waits for the dismissal to complete; in that gap the second item's confirm arrives.
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_1")!))
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in
                XCTFail("The second item is not presented while the first sheet is still dismissing")
            },
            "The second confirm stays on the PayPal path instead of running a card purchase"
        )
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey), "The second item is left pending, not consumed")

        // One turn later the first sheet has been asked to dismiss and is animating away; a confirm in that window still
        // waits, since the screen is still showing the first sheet.
        drainMainQueue(turns: 1)
        XCTAssertEqual(payPalPresenter.presentCallCount, 1, "No second sheet is presented over the dismissing one")
        XCTAssertNil(firstResult, "The first checkout's callback waits for its dismissal to complete")
        XCTAssertTrue(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in
                XCTFail("The second item is not presented while the first sheet is still dismissing")
            }
        )
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey))

        // The dismissal completes: the first checkout's callback runs, its mark goes, and nothing holds the second item.
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)
        XCTAssertEqual(firstResult?.outcome, .succeeded)
        XCTAssertEqual(firstResult?.transactionId, "ORDER_1")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 0, "The first sheet's mark went with its callback")
        XCTAssertNil(secondResult)

        // The next confirm presents the second item's approval, and its return link reaches it.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The second item's sheet is presented once the first is gone")
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: secondKey))
        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!))
        drainMainQueue()
        XCTAssertEqual(secondResult?.outcome, .succeeded)
        XCTAssertEqual(secondResult?.transactionId, "ORDER_2")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 0)
    }

    /// The host tears the first sheet down without a cancel or a return, and its checkout stays alive; the second
    /// item's confirm then presents. When the first checkout at last reports a cancel, the second sheet stays routable
    /// and the first item is re-queued for a later confirm. This is the pin of the identity check in the checkout's
    /// callback, which clears the active checkout only when it still names its own: a late callback never takes the
    /// routing away from the sheet presented after it. A checkout still held elsewhere is not pruned by the
    /// presentation that replaces it, and nothing is reported for it.
    func test_presentPendingBuiltInPayPal_aLateCancelFromAnAbandonedCheckoutStillAlive_leavesTheNextApprovalRoutable() {
        let payPalPresenter = RetainingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        var firstResult: PaymentSheetResult?
        var secondResult: PaymentSheetResult?
        func startStepOne(cartItemId: String, orderId: String, completion: @escaping (PaymentSheetResult) -> Void) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
                Self.validPayPalInitializePurchaseResponse(orderId: orderId)
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
                builtInPayPalDevicePaySession: paypalDeviceSessionForTests(),
                completion: completion
            )
        }
        startStepOne(cartItemId: "v1:cart:1", orderId: "ORDER_1") { firstResult = $0 }
        startStepOne(cartItemId: "v1:cart:2", orderId: "ORDER_2") { secondResult = $0 }
        let firstKey = testKey(cartItemId: "v1:cart:1")
        let secondKey = testKey(cartItemId: "v1:cart:2")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: firstKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentedCheckouts.count, 1)

        // The host takes the first sheet off screen without a cancel or a return; the checkout itself stays alive.
        payPalPresenter.presentedSheets.first?.tearDown()
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: secondKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentedCheckouts.count, 2, "The second item's approval sheet is presented")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 2, "A mark whose checkout is still held is not pruned")
        XCTAssertTrue(reported.isEmpty, "Nothing is reported for a checkout that may still report back")

        // The first checkout reports a cancel late, once the second sheet is already up.
        payPalPresenter.presentedCheckouts.first?.completeFromUserDismissal(.canceled)
        drainMainQueue()
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: firstKey), "The first item is re-queued for a later confirm")
        XCTAssertNil(firstResult, "A cancel defers the Step-1 completion")

        XCTAssertTrue(
            sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_2")!),
            "The second order's return link still reaches the checkout whose sheet is up"
        )
        drainMainQueue()
        XCTAssertEqual(secondResult?.outcome, .succeeded)
        XCTAssertEqual(secondResult?.transactionId, "ORDER_2")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 0)
        XCTAssertTrue(reported.isEmpty, "Both checkouts reported back on their own, so nothing was left for a report")
    }

    func test_presentPendingBuiltInPayPal_whenTheScreenAlreadyPresentsAnotherView_failsStepOneAndALaterItemStillPresents() {
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: PayPalApprovalWebPresenter()
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()
        // By the time the confirm is tapped, the screen that started Step-1 is showing another view (an alert, another
        // sheet), so the approval sheet cannot be shown and nothing would ever report back for it.
        let busyViewController = AlreadyPresentingViewController()
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
            from: busyViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { stepOneResult = $0 }
        var confirmResult: PaymentSheetResult?
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { confirmResult = $0 })
        drainMainQueue()

        XCTAssertEqual(stepOneResult?.outcome, .failed)
        XCTAssertEqual(stepOneResult?.errorMessage, PaymentOrchestrator.payPalApprovalPresenterBusyMessage)
        XCTAssertEqual(confirmResult?.outcome, .failed)
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertFalse(
            sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in },
            "The failed item is no longer counted as a sheet on screen"
        )

        // The presenter is fixed per orchestrator, so the later item runs through one whose screen can show a sheet;
        // the one-approval-at-a-time gate is shared between them, and the failed item must not hold it closed.
        let laterPresenter = HoldingPayPalApprovalPresenter()
        let laterOrchestrator = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: laterPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        let presentingViewController = UIViewController()
        laterOrchestrator.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p2", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:2",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { _ in }
        let laterKey = testKey(cartItemId: "v1:cart:2")
        XCTAssertTrue(laterOrchestrator.presentPendingBuiltInPayPalForForwardPayment(for: laterKey) { _ in })
        drainMainQueue()

        XCTAssertEqual(laterPresenter.presentCallCount, 1, "The later item's approval sheet is presented")
        XCTAssertFalse(laterOrchestrator.unitTest_hasPendingBuiltInTwoStep(for: laterKey))
    }

    func test_presentPendingBuiltInPayPal_screenNotInAWindowAndLayoutCloses_failsStepOneAndALaterItemStillPresents() {
        sut = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: PayPalApprovalWebPresenter()
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse()
        // By the time the confirm is tapped, the screen that started Step-1 is no longer showing (its view is in no
        // window), so UIKit would drop the approval sheet without ever reporting back for it.
        let offScreenViewController = UIViewController()
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
            from: offScreenViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests()
        ) { stepOneResult = $0 }
        var confirmResult: PaymentSheetResult?
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { confirmResult = $0 })
        // The placement closes before the present has run, so the item's mark is fenced. A fenced mark whose sheet
        // never reports back would otherwise hold every later PayPal confirm for the rest of the process.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        drainMainQueue()

        XCTAssertEqual(stepOneResult?.outcome, .failed)
        XCTAssertEqual(stepOneResult?.errorMessage, PaymentOrchestrator.payPalApprovalPresenterOffScreenMessage)
        XCTAssertEqual(confirmResult?.outcome, .failed)
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))

        // A later placement offers a PayPal item through an orchestrator whose screen can show a sheet; the
        // one-approval-at-a-time gate is shared between them, and the sheet that never opened must not hold it closed.
        let laterPresenter = HoldingPayPalApprovalPresenter()
        let laterOrchestrator = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: laterPresenter
        )
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        let presentingViewController = UIViewController()
        laterOrchestrator.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p2", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:2",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests(layoutId: "other_layout")
        ) { _ in }
        let laterKey = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId,
            layoutId: "other_layout",
            catalogItemId: "test_catalog",
            cartItemId: "v1:cart:2"
        )
        XCTAssertTrue(laterOrchestrator.presentPendingBuiltInPayPalForForwardPayment(for: laterKey) { _ in })
        drainMainQueue()

        XCTAssertEqual(laterPresenter.presentCallCount, 1, "The later item's approval sheet is presented")
        XCTAssertFalse(laterOrchestrator.unitTest_hasPendingBuiltInTwoStep(for: laterKey), "The later item's checkout started")
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

    // MARK: - Outstanding checkouts of an execute

    private func startPayPalStepOne(
        orderId: String,
        from presentingViewController: UIViewController,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse(orderId: orderId)
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
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests(),
            completion: completion
        )
    }

    func test_hasOutstandingBuiltInTwoStepCheckout_countsEveryStageOfThatExecutesCheckoutsOnly() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        let executeId = Self.testExecuteId
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId))

        let cardKey = testKey(cartItemId: "v1:cart:card")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: cardKey) { _ in }
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId), "A result waiting for its confirm")
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: "another_execute"))
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: cardKey))
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId), "A card purchase in flight")
        sut.finishBuiltInCardForwardPaymentAttempt(for: cardKey, result: .succeeded(transactionId: ""))
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId))

        // Held strongly until the deferred present has run; the pending checkout only keeps a weak reference.
        let presentingViewController = UIViewController()
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        startPayPalStepOne(orderId: "ORDER_1", from: presentingViewController) { _ in }
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId), "A Step-1 request still out")
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId), "A result waiting for its confirm")
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertEqual(payPalPresenter.presentCallCount, 1)
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId), "An approval sheet up")

        XCTAssertTrue(sut.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_1")!))
        drainMainQueue()
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: executeId))
    }

    func test_onExecuteHasNoOutstandingCheckout_reportsACancelThatDropsTheLastCheckoutOfAClosedPlacement() {
        let payPalPresenter = MockPayPalApprovalPresenter()
        payPalPresenter.sheetResult = .canceled
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let presentingViewController = UIViewController()
        startPayPalStepOne(orderId: "ORDER_1", from: presentingViewController) { _ in
            XCTFail("A cancel re-queues or drops the entry without reporting a result")
        }

        // With its placement still open, a cancel re-queues the entry: the checkout is still outstanding.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        drainMainQueue()
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertTrue(reported.isEmpty)

        // With its placement closed while the sheet is up, the cancel drops the entry and nothing of the execute is left.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: testKey()) { _ in })
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        drainMainQueue()
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    func test_onExecuteHasNoOutstandingCheckout_reportsARetryableFailureThatDropsTheLastCheckoutOfAClosedPlacement() {
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let firstKey = testKey(cartItemId: "v1:cart:1")
        let secondKey = testKey(cartItemId: "v1:cart:2")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: firstKey) { _ in XCTFail("A dropped entry reports nothing") }
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: secondKey) { _ in XCTFail("A dropped entry reports nothing") }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: firstKey))
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: secondKey))
        // The placement closes with both purchases in flight; each is kept until its own outcome.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: nil)

        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: firstKey)
        drainMainQueue()
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: firstKey))
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId), "The other is still out")
        XCTAssertTrue(reported.isEmpty, "Not reported while a checkout of the execute remains")

        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: secondKey)
        drainMainQueue()
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    func test_onExecuteHasNoOutstandingCheckout_reportsALayoutCloseThatDropsTheLastCheckoutOfTheExecute() {
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        sut.unitTest_seedDeferredBuiltInPayPalForwardPayment(
            for: testKey(),
            approvalURL: URL(string: "https://www.paypal.com/checkoutnow?token=MOCK")!,
            returnURLString: "myapp://paypal/success",
            orderId: "ORDER_MOCK"
        ) { _ in XCTFail("A dropped entry reports nothing") }

        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        drainMainQueue()

        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertEqual(reported, [Self.testExecuteId], "Reported once: a dropped checkout can never report back on its own")
    }

    func test_onExecuteHasNoOutstandingCheckout_reportsALayoutCloseThatDropsAStepOneStillOutForTheExecute() {
        var reported: [String] = []
        startHeldPayPalStepOne(
            onConfirmation: { XCTFail("No confirm button is shown for a placement that closed while the request was out") },
            onStepOneResult: { _ in XCTFail("Nothing is owed for a placement that is gone") }
        )
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }

        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        drainMainQueue()
        XCTAssertEqual(reported, [Self.testExecuteId])

        // The response that lands afterwards belongs to nobody, and reports nothing more.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        drainMainQueue()
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: testKey()))
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    func test_onExecuteHasNoOutstandingCheckout_isNotReportedByALayoutCloseWhileAnotherCheckoutOfTheExecuteRemains() {
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let closingKey = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId, layoutId: "closing_layout", catalogItemId: "test_catalog", cartItemId: "v1:cart:1"
        )
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: closingKey) { _ in XCTFail("A dropped entry reports nothing") }
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: testKey(cartItemId: "v1:cart:2")) { _ in }

        // A close that drops nothing of the execute reports nothing.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "empty_layout")
        drainMainQueue()
        XCTAssertTrue(reported.isEmpty)

        // The other open layout's checkout keeps the execute outstanding.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "closing_layout")
        drainMainQueue()
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: closingKey))
        XCTAssertTrue(reported.isEmpty, "Not reported while a checkout of the execute remains")

        // Once the last one is dropped, the execute is reported.
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        drainMainQueue()
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    func test_onExecuteHasNoOutstandingCheckout_aLayoutCloseThatFencesACardPurchaseInFlight_reportsOnlyWhenItDrops() {
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let inFlightKey = testKey(cartItemId: "v1:cart:1")
        let waitingKey = testKey(cartItemId: "v1:cart:2")
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: inFlightKey) { _ in XCTFail("A dropped entry reports nothing") }
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: waitingKey) { _ in XCTFail("A dropped entry reports nothing") }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: inFlightKey))

        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        drainMainQueue()
        XCTAssertFalse(sut.unitTest_hasPendingBuiltInTwoStep(for: waitingKey), "The confirm not yet tapped goes with its layout")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: inFlightKey), "The purchase already sent is kept")
        XCTAssertTrue(reported.isEmpty, "Not reported while the purchase already sent can still report back")

        sut.restoreBuiltInCardForwardPaymentAfterRetryableFailure(for: inFlightKey)
        drainMainQueue()
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    func test_onExecuteHasNoOutstandingCheckout_reportsEachExecuteASessionClearLeavesWithNothingOutstanding() {
        var reported: Set<String> = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.insert($0) }
        let waitingKey = BuiltInTwoStepCheckoutKey(
            executeId: "execute_waiting", layoutId: "l", catalogItemId: "c", cartItemId: "v1:cart:1"
        )
        let inFlightKey = BuiltInTwoStepCheckoutKey(
            executeId: "execute_in_flight", layoutId: "l", catalogItemId: "c", cartItemId: "v1:cart:2"
        )
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: waitingKey) { _ in XCTFail("A dropped entry reports nothing") }
        sut.unitTest_seedDeferredBuiltInCardForwardPayment(for: inFlightKey) { _ in }
        XCTAssertNotNil(sut.beginBuiltInCardForwardPaymentIfReady(for: inFlightKey))

        sut.discardAllPendingBuiltInTwoStep()
        drainMainQueue()

        XCTAssertEqual(reported, ["execute_waiting"], "A purchase still in flight keeps its execute outstanding")
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: "execute_in_flight"))
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: "execute_waiting"))
    }

    // MARK: - A pruned mark of an abandoned approval reports its execute

    private static let otherExecuteKey = BuiltInTwoStepCheckoutKey(
        executeId: "other_execute", layoutId: "other_layout", catalogItemId: "other_catalog", cartItemId: "v1:cart:other"
    )

    /// Starts built-in PayPal Step-1 for `key` and presents its approval sheet from `presentingViewController`, which the
    /// test holds strongly for as long as the sheet must stay presentable. Runs through `orchestrator` when one is given
    /// (an orchestrator the test lets go of later), otherwise through the one under test.
    private func presentPayPalCheckout(
        for key: BuiltInTwoStepCheckoutKey,
        orderId: String,
        from presentingViewController: UIViewController,
        through orchestrator: PaymentOrchestrator? = nil,
        onStepOneResult: @escaping (PaymentSheetResult) -> Void = { _ in }
    ) {
        let orchestrator: PaymentOrchestrator = orchestrator ?? sut
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = Self.validPayPalInitializePurchaseResponse(orderId: orderId)
        orchestrator.processPayment(
            method: .paypal,
            item: PaymentItem(id: key.catalogItemId, name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: key.cartItemId,
            from: presentingViewController,
            builtInPayPalDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: key.executeId,
                layoutId: key.layoutId,
                catalogItemId: key.catalogItemId
            ) { _, _, _ in },
            completion: onStepOneResult
        )
        XCTAssertTrue(orchestrator.presentPendingBuiltInPayPalForForwardPayment(for: key) { _ in })
        drainMainQueue()
    }

    /// Leaves the test execute with a mark whose checkout may be gone, with no pass having run since: its PayPal
    /// approval is presented through an orchestrator built on `payPalPresenter` that this helper then lets go of, its
    /// placement closes while the sheet is up, the host tears the sheet down without a cancel or a return
    /// (`tearDownSheet`), another execute's approval presents through the orchestrator under test while the first
    /// checkout is still held, and the orchestrator that presented the first approval then goes away. With a presenter
    /// that does not hold its checkouts, that release orphans the mark, the other way a mark is orphaned (a
    /// presentation that releases the checkout prunes the mark itself); the mark stays until a later pass prunes it.
    private func abandonTheTestExecutesApproval(
        payPalPresenter: PayPalApprovalPresenting,
        from presentingViewController: UIViewController,
        tearDownSheet: () -> Void,
        onStepOneResult: @escaping (PaymentSheetResult) -> Void = { _ in }
    ) {
        var releasedOrchestrator: PaymentOrchestrator? = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: payPalPresenter
        )
        presentPayPalCheckout(
            for: testKey(),
            orderId: "ORDER_1",
            from: presentingViewController,
            through: releasedOrchestrator,
            onStepOneResult: onStepOneResult
        )
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        tearDownSheet()
        presentPayPalCheckout(for: Self.otherExecuteKey, orderId: "ORDER_OTHER", from: presentingViewController)
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 2, "The first checkout is still held, so nothing is pruned")
        // The orchestrator that presented the first approval goes away, taking the last reference to that checkout with
        // it unless the presenter holds one; no pass runs at this point.
        releasedOrchestrator = nil
    }

    func test_presentPendingBuiltInPayPal_pruningTheLastMarkOfAnExecuteWhoseCheckoutIsGone_reportsThatExecute() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        abandonTheTestExecutesApproval(
            payPalPresenter: payPalPresenter,
            from: presentingViewController,
            tearDownSheet: { payPalPresenter.presentedSheets.first?.tearDown() },
            onStepOneResult: { _ in XCTFail("An approval that never reported back owes nothing") }
        )
        XCTAssertTrue(reported.isEmpty, "Nothing has been pruned yet, so nothing is reported")

        // A repeated confirm for the other item has nothing to start, but prunes the first mark on its way in. Nothing
        // of the first execute is left, so that execute is reported; the other execute's approval is still up.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: Self.otherExecuteKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "Only the mark of the approval still up is left")
        XCTAssertEqual(reported, [Self.testExecuteId])
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.otherExecuteKey.executeId))
    }

    func test_presentPendingBuiltInPayPal_keepsTheMarkOfAnAbandonedApprovalWhoseCheckoutIsStillHeld_andReportsNothing() {
        let payPalPresenter = RetainingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let presentingViewController = UIViewController()
        abandonTheTestExecutesApproval(
            payPalPresenter: payPalPresenter,
            from: presentingViewController,
            tearDownSheet: { payPalPresenter.presentedSheets.first?.tearDown() }
        )

        // The first checkout is still held, so a late cancel or return may yet reach it: its mark stays, it still counts
        // for its execute, and nothing is reported.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: Self.otherExecuteKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 2, "A mark whose checkout is held is not pruned")
        XCTAssertTrue(reported.isEmpty)
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
    }

    func test_hasOutstandingBuiltInTwoStepCheckout_leavesAMarkWhoseCheckoutIsGoneForAPassThatReportsWhatItPrunes() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let presentingViewController = UIViewController()
        abandonTheTestExecutesApproval(
            payPalPresenter: payPalPresenter,
            from: presentingViewController,
            tearDownSheet: { payPalPresenter.presentedSheets.first?.tearDown() }
        )

        // The read runs inside the state keeper's own release check, so it changes nothing: the mark whose checkout is
        // gone does not count, but stays for a pass that reports what it prunes, and no report is sent from a read.
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.otherExecuteKey.executeId))
        drainMainQueue()
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 2, "The read prunes nothing")
        XCTAssertTrue(reported.isEmpty, "The read reports nothing")

        // The next confirm is the pass that prunes the mark and reports its execute.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: Self.otherExecuteKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1)
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    func test_stepOne_payPal_whoseResponsePrunesTheLastMarkOfAnExecuteWhoseCheckoutIsGone_reportsThatExecute() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let presentingViewController = UIViewController()
        abandonTheTestExecutesApproval(
            payPalPresenter: payPalPresenter,
            from: presentingViewController,
            tearDownSheet: { payPalPresenter.presentedSheets.first?.tearDown() }
        )

        // Step-1 for a second item of the first execute fails, so nothing is stored for it, and its response prunes the
        // first item's mark on the way. Nothing of the first execute is left, so that execute is reported; the other is not.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = nil
        var stepOneResult: PaymentSheetResult?
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p2", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:2",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests(layoutId: "second_layout") { _, _, _ in
                XCTFail("A failed Step-1 shows no confirm button")
            }
        ) { stepOneResult = $0 }
        drainMainQueue()

        XCTAssertEqual(stepOneResult?.outcome, .failed, "The layout still hears that this attempt failed")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "Only the mark of the approval still up is left")
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    func test_stepOne_payPal_whoseResponseStoresANewCheckoutOfTheExecute_prunesAnAbandonedMarkAndReportsNothing() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let presentingViewController = UIViewController()
        abandonTheTestExecutesApproval(
            payPalPresenter: payPalPresenter,
            from: presentingViewController,
            tearDownSheet: { payPalPresenter.presentedSheets.first?.tearDown() }
        )

        // Step-1 for a second item of the first execute succeeds and stores its checkout. Its response prunes the first
        // item's mark on the way, but the new checkout keeps the execute outstanding, so nothing is reported for it.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse =
            Self.validPayPalInitializePurchaseResponse(orderId: "ORDER_2")
        var confirmationShown = false
        sut.processPayment(
            method: .paypal,
            item: PaymentItem(id: "p2", name: "P", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "v1:cart:2",
            from: presentingViewController,
            builtInPayPalDevicePaySession: paypalDeviceSessionForTests(layoutId: "second_layout") { _, _, _ in
                confirmationShown = true
            }
        ) { _ in }
        drainMainQueue()
        let secondItemKey = BuiltInTwoStepCheckoutKey(
            executeId: Self.testExecuteId,
            layoutId: "second_layout",
            catalogItemId: "test_catalog",
            cartItemId: "v1:cart:2"
        )

        XCTAssertTrue(confirmationShown, "The new checkout is on offer")
        XCTAssertTrue(sut.unitTest_hasPendingBuiltInTwoStep(for: secondItemKey))
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "The mark of the approval that is gone is pruned")
        XCTAssertTrue(reported.isEmpty, "Not reported while the new checkout of the execute waits for its confirm")
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
    }

    func test_stepOne_card_whoseResponsePrunesTheLastMarkOfAnExecuteWhoseCheckoutIsGone_reportsThatExecute() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        let presentingViewController = UIViewController()
        abandonTheTestExecutesApproval(
            payPalPresenter: payPalPresenter,
            from: presentingViewController,
            tearDownSheet: { payPalPresenter.presentedSheets.first?.tearDown() }
        )

        // A card Step-1 for a second item of the first execute fails, so nothing is stored for it, and its response prunes
        // the first item's mark on the way. Nothing of the first execute is left, so that execute is reported.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = nil
        var stepOneResult: PaymentSheetResult?
        sut.processPayment(
            method: .card,
            item: PaymentItem(id: "item-card", name: "Widget", amount: 9.99, currency: "USD"),
            context: PaymentContext(),
            cartItemId: "v1:cart:2",
            from: presentingViewController,
            builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: Self.testExecuteId,
                layoutId: "second_layout",
                catalogItemId: "test_catalog"
            ) { _, _, _ in
                XCTFail("A failed Step-1 shows no confirm button")
            }
        ) { stepOneResult = $0 }
        drainMainQueue()

        XCTAssertEqual(stepOneResult?.outcome, .failed, "The layout still hears that this attempt failed")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "Only the mark of the approval still up is left")
        XCTAssertEqual(reported, [Self.testExecuteId])
    }

    // MARK: - A presentation that releases an abandoned checkout prunes its mark

    /// A PayPal sheet is up when the host tears it down without a cancel or a return; its checkout stays alive only
    /// through the orchestrator's active checkout. Another execute's confirm then presents in its place: the assignment
    /// that makes the new checkout active releases the old one, and that same step prunes its mark and reports its
    /// execute, once, rather than leaving both to a later pass that might never run.
    func test_presentPendingBuiltInPayPal_theNextPresentationReleasesATornDownCheckout_prunesItsMarkAndReportsItsExecute() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        presentPayPalCheckout(
            for: testKey(),
            orderId: "ORDER_1",
            from: presentingViewController,
            onStepOneResult: { _ in XCTFail("An approval that never reported back owes nothing") }
        )
        sut.discardPendingBuiltInTwoStep(forExecuteId: Self.testExecuteId, layoutId: "test_layout")
        payPalPresenter.presentedSheets.first?.tearDown()
        XCTAssertTrue(reported.isEmpty, "The checkout is still held, so its execute is still outstanding")

        presentPayPalCheckout(for: Self.otherExecuteKey, orderId: "ORDER_OTHER", from: presentingViewController)

        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The other execute's approval sheet is presented")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "The torn-down sheet's mark went at the replacement")
        XCTAssertEqual(reported, [Self.testExecuteId], "The execute left with nothing outstanding is reported at once")
        XCTAssertFalse(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.otherExecuteKey.executeId))

        // A repeated confirm for the other item has nothing to start and nothing left to prune: no second report.
        XCTAssertTrue(sut.presentPendingBuiltInPayPalForForwardPayment(for: Self.otherExecuteKey) { _ in })
        drainMainQueue()
        XCTAssertEqual(reported, [Self.testExecuteId], "Reported once, not again")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1)
    }

    /// Two items of one placement, the layout still open. The host tears the first item's sheet down, and the second
    /// item's confirm presents in its place, releasing the first checkout. The first mark is pruned at that step, but the
    /// new checkout keeps the execute outstanding, so nothing is reported for it.
    func test_presentPendingBuiltInPayPal_theNextPresentationReleasesATornDownCheckoutOfItsOwnExecute_reportsNothing() {
        let payPalPresenter = HoldingPayPalApprovalPresenter()
        sut = PaymentOrchestrator(apiHelper: PaymentOrchestratorAPIHelperSpy.self, payPalApprovalPresenter: payPalPresenter)
        var reported: [String] = []
        sut.onExecuteHasNoOutstandingCheckout = { reported.append($0) }
        // Held strongly until the deferred presents have run; the pending checkouts only keep a weak reference.
        let presentingViewController = UIViewController()
        presentPayPalCheckout(
            for: testKey(cartItemId: "v1:cart:1"),
            orderId: "ORDER_1",
            from: presentingViewController,
            onStepOneResult: { _ in XCTFail("An approval that never reported back owes nothing") }
        )
        payPalPresenter.presentedSheets.first?.tearDown()

        presentPayPalCheckout(for: testKey(cartItemId: "v1:cart:2"), orderId: "ORDER_2", from: presentingViewController)

        XCTAssertEqual(payPalPresenter.presentCallCount, 2, "The second item's approval sheet is presented")
        XCTAssertEqual(sut.unitTest_presentedBuiltInPayPalCount(), 1, "The torn-down sheet's mark went at the replacement")
        XCTAssertTrue(reported.isEmpty, "The second item's approval keeps the execute outstanding")
        XCTAssertTrue(sut.hasOutstandingBuiltInTwoStepCheckout(forExecuteId: Self.testExecuteId))
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
    /// When `true`, `initializePurchase` keeps its response back until `releaseHeldInitializePurchase()` runs, so a
    /// test can act while the request is still out.
    static var holdInitializePurchaseResponse = false
    private static var heldInitializePurchaseDelivery: (() -> Void)?

    static func releaseHeldInitializePurchase() {
        let delivery = heldInitializePurchaseDelivery
        heldInitializePurchaseDelivery = nil
        delivery?()
    }

    static func reset() {
        holdInitializePurchaseResponse = false
        heldInitializePurchaseDelivery = nil
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
        let response = initializePurchaseResponse
        let deliver: () -> Void = {
            if let response {
                success?(response)
            } else {
                let error = NSError(
                    domain: "RoktSDK",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing test initializePurchase response"]
                )
                failure?(error, 500, "Missing test initializePurchase response")
            }
        }
        if holdInitializePurchaseResponse {
            heldInitializePurchaseDelivery = deliver
        } else {
            deliver()
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
