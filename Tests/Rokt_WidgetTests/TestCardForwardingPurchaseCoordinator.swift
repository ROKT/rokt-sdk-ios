import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper
import Mocker

/// Card forwarding cart purchase coordinator: finalize vs restore when `/v1/cart/purchase` returns,
/// plus ``RoktInternalImplementation/handleForwardPayment`` instant-purchase flag behavior with card in flight.
final class TestCardForwardingPurchaseCoordinator: XCTestCase {

    private let purchaseURL = URL(string: "https://apps.rokt.com/rokt-mobile/v1/cart/purchase")!
    private let executeId = "card-forwarding-coordinator-test"

    private var originalTagId: String?

    private let forwardPaymentTestTagId = "test-tag-id"

    override func setUp() {
        super.setUp()
        Rokt.setEnvironment(environment: .Prod)
        originalTagId = Rokt.shared.roktImplementation.roktTagId
        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
    }

    override func tearDown() {
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
        Rokt.shared.roktImplementation.roktTagId = originalTagId
        super.tearDown()
    }

    // MARK: - Helpers

    /// ``RoktNetWorkAPI.forwardPayment`` reads the tag id on ``Rokt/shared``; parallel suites can clear it in `tearDown`, so re-apply before each network call.
    private func ensureForwardPaymentTagIdForNetwork() {
        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
    }

    private func makeForwardPaymentEvent() -> RoktUXEvent.CartItemForwardPayment {
        RoktUXEvent.CartItemForwardPayment(
            layoutId: "layout-1",
            name: "Test item",
            cartItemId: "cart-1",
            catalogItemId: "catalog-1",
            currency: "USD",
            description: "desc",
            linkedProductId: nil,
            providerData: "provider",
            quantity: 1,
            totalPrice: 9.99,
            unitPrice: 9.99,
            transactionData: nil
        )
    }

    private func installMockingHTTPClient() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)
    }

    private func registerPurchaseMock(statusCode: Int, body: String, onRequest: ((URLRequest) -> Void)? = nil) {
        var mock = Mock(
            url: purchaseURL,
            dataType: .json,
            statusCode: statusCode,
            data: [.post: Data(body.utf8)]
        )
        mock.onRequest = { request, _ in
            onRequest?(request)
        }
        mock.register()
    }

    /// - Parameter assertNoStepOneCompletion: When `true`, Step-1 completion fails the test if invoked (used for retry / restore flows where Step-1 must stay open). When `false`, Step-1 may complete after a terminal ``finishBuiltInCardForwardPaymentAttempt``.
    private func seedDeferredBuiltInCardForwardPaymentReady(
        orch: PaymentOrchestrator,
        assertNoStepOneCompletion: Bool = true
    ) {
        orch.unitTest_seedDeferredBuiltInCardForwardPayment { _ in
            if assertNoStepOneCompletion {
                XCTFail("Step-1 completion must not run until terminal finish")
            }
        }
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight(), "Coordinator expects .card, not .cardInFlight, before begin")
    }

    private final class FinalizeInvocationLog {
        private(set) var invocations: [(success: Bool, failureReason: String?)] = []
        func record(success: Bool, failureReason: String?) {
            invocations.append((success, failureReason))
        }
    }

    private func makeCoordinator(
        orch: PaymentOrchestrator,
        finalizeLog: FinalizeInvocationLog,
        hideLoadingExpectation: XCTestExpectation? = nil
    ) -> BuiltInCardForwardingPurchaseCoordinator {
        BuiltInCardForwardingPurchaseCoordinator(
            paymentOrchestrator: orch,
            unknownFailureReason: RoktInternalImplementation.unknownForwardPaymentFailureReason,
            missingPriceFailureReason: RoktInternalImplementation.missingForwardPaymentPriceReason,
            resolveCartPurchaseFinalization: { RoktInternalImplementation.resolveForwardPaymentFinalization(from: $0) },
            resolveTransportFailureFinalization: {
            RoktInternalImplementation.resolveForwardPaymentFinalization(fromFailureMessage: $0) },
            emitRoktEvent: { _, event in
                if event is RoktEvent.HideLoadingIndicator {
                    hideLoadingExpectation?.fulfill()
                }
            },
            finalizeForwardPayment: { _, _, _, success, failureReason in
                finalizeLog.record(success: success, failureReason: failureReason)
            }
        )
    }

    // MARK: - Coordinator + PaymentOrchestrator

    func test_cardInFlight_retryableHTTP503_skipsFinalize_restoresPendingCard() {
        let finalizeLog = FinalizeInvocationLog()
        let hideExp = expectation(description: "Hide loading after transport failure")
        let orch = PaymentOrchestrator()
        seedDeferredBuiltInCardForwardPaymentReady(orch: orch)

        registerPurchaseMock(statusCode: 503, body: "{}")
        installMockingHTTPClient()

        let sut = makeCoordinator(orch: orch, finalizeLog: finalizeLog, hideLoadingExpectation: hideExp)
        ensureForwardPaymentTagIdForNetwork()
        sut.performCardForwardingCartPurchase(executeId: executeId, event: makeForwardPaymentEvent())

        wait(for: [hideExp], timeout: 3.0)
        XCTAssertTrue(finalizeLog.invocations.isEmpty, "Retryable transport failure must not call forwardPaymentFinalized")
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight(), "Restore moves cardInFlight back to card")
        XCTAssertNotNil(orch.beginBuiltInCardForwardPaymentIfReady(), "Buyer can start a second cart purchase after restore")
    }

    func test_cardInFlight_retryableBusinessReason_skipsFinalize_restoresPendingCard() {
        let finalizeLog = FinalizeInvocationLog()
        let hideExp = expectation(description: "Hide loading after HTTP 200 business failure")
        let orch = PaymentOrchestrator()
        seedDeferredBuiltInCardForwardPaymentReady(orch: orch)

        registerPurchaseMock(statusCode: 200, body: #"{"success":false,"reason":"Upstream timeout"}"#)
        installMockingHTTPClient()

        let sut = makeCoordinator(orch: orch, finalizeLog: finalizeLog, hideLoadingExpectation: hideExp)
        ensureForwardPaymentTagIdForNetwork()
        sut.performCardForwardingCartPurchase(executeId: executeId, event: makeForwardPaymentEvent())

        wait(for: [hideExp], timeout: 3.0)
        XCTAssertTrue(finalizeLog.invocations.isEmpty)
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())
        XCTAssertNotNil(orch.beginBuiltInCardForwardPaymentIfReady())
    }

    func test_cardInFlight_terminalBusinessReason_invokesFinalizeAndClearsDeferredState() {
        let finalizeLog = FinalizeInvocationLog()
        let hideExp = expectation(description: "Hide loading")
        let orch = PaymentOrchestrator()
        seedDeferredBuiltInCardForwardPaymentReady(orch: orch, assertNoStepOneCompletion: false)

        registerPurchaseMock(statusCode: 200, body: #"{"success":false,"reason":"declined"}"#)
        installMockingHTTPClient()

        let sut = makeCoordinator(orch: orch, finalizeLog: finalizeLog, hideLoadingExpectation: hideExp)
        ensureForwardPaymentTagIdForNetwork()
        sut.performCardForwardingCartPurchase(executeId: executeId, event: makeForwardPaymentEvent())

        wait(for: [hideExp], timeout: 3.0)
        XCTAssertEqual(finalizeLog.invocations.count, 1)
        XCTAssertEqual(finalizeLog.invocations.first?.success, false)
        XCTAssertEqual(finalizeLog.invocations.first?.failureReason, "declined")
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())
        XCTAssertNil(orch.beginBuiltInCardForwardPaymentIfReady())
    }

    func test_cardInFlight_success_invokesFinalizeWithSuccess() {
        let finalizeLog = FinalizeInvocationLog()
        let hideExp = expectation(description: "Hide loading")
        let orch = PaymentOrchestrator()
        seedDeferredBuiltInCardForwardPaymentReady(orch: orch, assertNoStepOneCompletion: false)

        registerPurchaseMock(statusCode: 200, body: #"{"success":true}"#)
        installMockingHTTPClient()

        let sut = makeCoordinator(orch: orch, finalizeLog: finalizeLog, hideLoadingExpectation: hideExp)
        ensureForwardPaymentTagIdForNetwork()
        sut.performCardForwardingCartPurchase(executeId: executeId, event: makeForwardPaymentEvent())

        wait(for: [hideExp], timeout: 3.0)
        XCTAssertEqual(finalizeLog.invocations.count, 1)
        XCTAssertEqual(finalizeLog.invocations.first?.success, true)
        XCTAssertNil(finalizeLog.invocations.first?.failureReason)
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())
    }

    func test_cardInFlight_nonRetryableTransport_invokesFinalize() {
        let finalizeLog = FinalizeInvocationLog()
        let hideExp = expectation(description: "Hide loading")
        let orch = PaymentOrchestrator()
        seedDeferredBuiltInCardForwardPaymentReady(orch: orch, assertNoStepOneCompletion: false)

        registerPurchaseMock(statusCode: 400, body: #"{"error":"bad request"}"#)
        installMockingHTTPClient()

        let sut = makeCoordinator(orch: orch, finalizeLog: finalizeLog, hideLoadingExpectation: hideExp)
        ensureForwardPaymentTagIdForNetwork()
        sut.performCardForwardingCartPurchase(executeId: executeId, event: makeForwardPaymentEvent())

        wait(for: [hideExp], timeout: 3.0)
        XCTAssertEqual(finalizeLog.invocations.count, 1)
        XCTAssertEqual(finalizeLog.invocations.first?.success, false)
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())
    }

    // MARK: - RoktInternalImplementation + instant purchase flag

    private func expectFlagCleared(_ bag: ExecuteStateBag) -> XCTestExpectation {
        let exp = expectation(description: "instantPurchaseInitiated cleared")
        func check() {
            if !bag.instantPurchaseInitiated {
                exp.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: check)
            }
        }
        DispatchQueue.main.async(execute: check)
        return exp
    }

    func test_handleForwardPayment_cardInFlight_retryableBusinessReason_keepsInstantPurchaseInitiated() {
        let impl = RoktInternalImplementation()
        let orch = impl.paymentOrchestratorForTesting
        seedDeferredBuiltInCardForwardPaymentReady(orch: orch)

        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        bag.loadedPlacements = 1
        bag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: executeId, state: bag)

        registerPurchaseMock(statusCode: 200, body: #"{"success":false,"reason":"Please try again"}"#)
        installMockingHTTPClient()

        ensureForwardPaymentTagIdForNetwork()
        impl.handleForwardPayment(executeId: executeId, event: makeForwardPaymentEvent())

        let settled = expectation(description: "async network settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 2.0)

        XCTAssertTrue(bag.instantPurchaseInitiated, "forwardPaymentFinalized must be skipped until a terminal outcome")
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())
    }

    func test_handleForwardPayment_cardInFlight_terminalBusinessReason_clearsInstantPurchaseInitiated() {
        let impl = RoktInternalImplementation()
        let orch = impl.paymentOrchestratorForTesting
        seedDeferredBuiltInCardForwardPaymentReady(orch: orch, assertNoStepOneCompletion: false)

        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        bag.loadedPlacements = 1
        bag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: executeId, state: bag)

        registerPurchaseMock(statusCode: 200, body: #"{"success":false,"reason":"declined"}"#)
        installMockingHTTPClient()

        let cleared = expectFlagCleared(bag)
        ensureForwardPaymentTagIdForNetwork()
        impl.handleForwardPayment(executeId: executeId, event: makeForwardPaymentEvent())

        wait(for: [cleared], timeout: 3.0)
        XCTAssertFalse(bag.instantPurchaseInitiated)
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())
    }
}
