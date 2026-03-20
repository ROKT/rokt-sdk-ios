import XCTest
import UIKit
import RoktContracts

@testable import Rokt_Widget

// MARK: - Mock

final class MockPaymentExtension: PaymentExtension {
    let id: String
    let extensionDescription: String
    let supportedMethods: [PaymentMethodType]

    var shouldRegisterSuccessfully: Bool = true
    var paymentResultToReturn: PaymentResult = .succeeded(transactionId: "txn_mock")

    private(set) var onRegisterCallCount = 0
    private(set) var onRegisterLastParameters: [String: String]?
    private(set) var onUnregisterCallCount = 0
    private(set) var presentPaymentSheetCallCount = 0
    private(set) var presentPaymentSheetLastMethod: PaymentMethodType?
    private(set) var presentPaymentSheetLastItem: PaymentItem?

    init(
        id: String = "mock_extension",
        extensionDescription: String = "Mock Payment Extension",
        supportedMethods: [PaymentMethodType] = [.applePay]
    ) {
        self.id = id
        self.extensionDescription = extensionDescription
        self.supportedMethods = supportedMethods
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
        from viewController: UIViewController,
        preparePayment: @escaping (@Sendable (ContactAddress) async throws -> PaymentPreparation),
        completion: @escaping (PaymentResult) -> Void
    ) {
        presentPaymentSheetCallCount += 1
        presentPaymentSheetLastMethod = method
        presentPaymentSheetLastItem = item
        completion(paymentResultToReturn)
    }
}

// MARK: - Tests

class TestPaymentOrchestrator: XCTestCase {

    private var sut: PaymentOrchestrator!

    override func setUp() {
        super.setUp()
        sut = PaymentOrchestrator()
    }

    override func tearDown() {
        sut = nil
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
        XCTAssertEqual(sut.availablePaymentMethods(), [.card])
    }

    func test_register_duplicateId_removesOldEvenWhenNewFails() {
        let first = MockPaymentExtension(id: "stripe")
        sut.register(first, config: [:])

        let second = MockPaymentExtension(id: "stripe")
        second.shouldRegisterSuccessfully = false
        sut.register(second, config: [:])

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

        sut.processPayment(method: .card, item: item, cartItemId: "v1:cart-123:canal", from: vc) { result in
            if case .succeeded(let txnId) = result {
                XCTAssertEqual(txnId, "txn_card")
            } else {
                XCTFail("Expected succeeded result")
            }
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

        sut.processPayment(method: .applePay, item: item, cartItemId: "v1:cart-456:canal", from: vc) { result in
            if case .failed(let error) = result {
                XCTAssertTrue(error.contains("No payment extension found"),
                              "Error should indicate no extension found, got: \(error)")
            } else {
                XCTFail("Expected failed result, got: \(result)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
