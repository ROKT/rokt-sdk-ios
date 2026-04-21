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

// MARK: - Tests

class TestPaymentOrchestrator: XCTestCase {

    private var sut: PaymentOrchestrator!

    override func setUp() {
        super.setUp()
        sut = PaymentOrchestrator()
        PaymentOrchestratorAPIHelperSpy.reset()
    }

    override func tearDown() {
        sut = nil
        PaymentOrchestratorAPIHelperSpy.reset()
        super.tearDown()
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
            )
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
    }
}

class PaymentOrchestratorAPIHelperSpy: RoktAPIHelper {
    static var initializePurchaseResponse: InitializePurchaseResponse?
    static var sendDiagnosticsCallCount = 0
    static var lastDiagnosticsMessage: String?
    static var lastDiagnosticsCallStack: String?

    static func reset() {
        initializePurchaseResponse = nil
        sendDiagnosticsCallCount = 0
        lastDiagnosticsMessage = nil
        lastDiagnosticsCallStack = nil
    }

    override class func initializePurchase(
        upsellItems: [UpsellItem],
        shippingAttributes: ShippingAttributes,
        success: ((InitializePurchaseResponse) -> Void)?,
        failure: ((Error, Int?, String) -> Void)?
    ) {
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
