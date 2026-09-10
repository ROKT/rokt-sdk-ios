import Mocker
import RoktContracts
import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

/// Deferred built-in two-step state is bound to the item and placement that started it: a Step-2 confirm for a
/// different item runs its own cart purchase and leaves the other entry alone, and state not yet in flight is
/// dropped when its layout closes or fails, or the session is cleared; a purchase already sent keeps its result.
/// The execute's own state outlives its placements while any checkout of that execute is still outstanding.
final class TestBuiltInTwoStepCheckoutBinding: XCTestCase {

    private let purchaseURL = URL(string: "https://apps.rokt.com/rokt-mobile/v1/cart/purchase")!
    private let executeId = "two-step-binding-test"
    private let forwardPaymentTestTagId = "test-tag-id"

    private var originalTagId: String?
    private var originalHTTPClient: HTTPClientAdapter?

    /// Scratch session store so `clearSession()` never touches `UserDefaults.standard` in tests.
    private final class ScratchTxnStore: TxnSessionStore {
        private var values: [String: String] = [:]
        func string(forKey key: String) -> String? { values[key] }
        func setString(_ value: String, forKey key: String) { values[key] = value }
        func removeValue(forKey key: String) { values[key] = nil }
    }

    override func setUp() {
        super.setUp()
        Rokt.setEnvironment(environment: .Prod)
        originalTagId = Rokt.shared.roktImplementation.roktTagId
        originalHTTPClient = NetworkingHelper.shared.httpClient
        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
    }

    override func tearDown() {
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
        NetworkingHelper.shared.httpClient = originalHTTPClient
        Rokt.shared.roktImplementation.roktTagId = originalTagId
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeForwardPaymentEvent(
        layoutId: String = "layout-1",
        cartItemId: String,
        catalogItemId: String
    ) -> RoktUXEvent.CartItemForwardPayment {
        RoktUXEvent.CartItemForwardPayment(
            layoutId: layoutId,
            name: "Test item",
            cartItemId: cartItemId,
            catalogItemId: catalogItemId,
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

    private func key(
        executeId: String? = nil,
        layoutId: String = "layout-1",
        cartItemId: String,
        catalogItemId: String
    ) -> BuiltInTwoStepCheckoutKey {
        BuiltInTwoStepCheckoutKey(
            executeId: executeId ?? self.executeId,
            layoutId: layoutId,
            catalogItemId: catalogItemId,
            cartItemId: cartItemId
        )
    }

    /// Seeds a pending PayPal Step-1 whose completion must never run in these tests.
    private func seedPayPal(_ orch: PaymentOrchestrator, for key: BuiltInTwoStepCheckoutKey) {
        orch.unitTest_seedDeferredBuiltInPayPalForwardPayment(
            for: key,
            approvalURL: URL(string: "https://www.paypal.com/checkoutnow?token=MOCK")!,
            returnURLString: "myapp://paypal/success",
            orderId: "ORDER_MOCK"
        ) { _ in
            XCTFail("A pending PayPal checkout for another item or a closed placement must never complete")
        }
    }

    /// Seeds a pending card Step-1 whose completion must never run in these tests.
    private func seedCard(_ orch: PaymentOrchestrator, for key: BuiltInTwoStepCheckoutKey) {
        orch.unitTest_seedDeferredBuiltInCardForwardPayment(for: key) { _ in
            XCTFail("A pending card checkout for a closed placement must never complete")
        }
    }

    private func installMockingHTTPClient() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)
    }

    private func registerPurchaseMock(body: String, onRequest: @escaping (URLRequest) -> Void) {
        var mock = Mock(
            url: purchaseURL,
            dataType: .json,
            statusCode: 200,
            data: [.post: Data(body.utf8)]
        )
        mock.onRequest = { request, _ in
            onRequest(request)
        }
        mock.register()
    }

    /// An implementation with a state bag whose instant-purchase flag is set, as after the Step-2 tap;
    /// `forwardPaymentFinalized` clears the flag, which is how the tests observe that the event's own flow ran.
    private func makeImplementationAfterStepTwoTap() -> (RoktInternalImplementation, ExecuteStateBag) {
        let impl = RoktInternalImplementation()
        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        bag.loadedPlacements = 1
        bag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: executeId, state: bag)
        return (impl, bag)
    }

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

    private func drainMainQueue() {
        for _ in 0..<2 {
            let flush = expectation(description: "main queue flush")
            DispatchQueue.main.async { flush.fulfill() }
            wait(for: [flush], timeout: 1.0)
        }
    }

    private func requestBodyText(_ request: URLRequest) -> String {
        guard let json = request.bodyStreamAsJSON(),
              let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(bytes: data, encoding: .utf8)
        else { return "" }
        return text
    }

    // MARK: - Step-2 resumes only its own item's Step-1

    func test_handleForwardPayment_pendingPayPalForAnotherItem_runsTheEventsOwnCartPurchase() {
        let (impl, bag) = makeImplementationAfterStepTwoTap()
        let orch = impl.paymentOrchestratorForTesting
        let itemAKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        seedPayPal(orch, for: itemAKey)

        let requestSent = expectation(description: "cart purchase sent for item B")
        var requestBodies: [String] = []
        registerPurchaseMock(body: #"{"success":true}"#) { request in
            requestBodies.append(self.requestBodyText(request))
            requestSent.fulfill()
        }
        installMockingHTTPClient()
        let cleared = expectFlagCleared(bag)

        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(cartItemId: "cart-b", catalogItemId: "catalog-b")
        )

        wait(for: [requestSent, cleared], timeout: 3.0)
        XCTAssertEqual(requestBodies.count, 1)
        XCTAssertTrue(requestBodies.first?.contains("cart-b") == true, "The purchase carries the confirmed item")
        XCTAssertFalse(requestBodies.first?.contains("cart-a") == true, "The purchase never carries the other item")
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: itemAKey), "Item A stays pending for its own confirm")
    }

    func test_handleForwardPayment_pendingPayPalForSameItemInAnotherPlacement_runsTheEventsOwnCartPurchase() {
        let (impl, bag) = makeImplementationAfterStepTwoTap()
        let orch = impl.paymentOrchestratorForTesting
        let otherPlacementKey = key(executeId: "other-execute", cartItemId: "cart-a", catalogItemId: "catalog-a")
        seedPayPal(orch, for: otherPlacementKey)

        let requestSent = expectation(description: "cart purchase sent")
        registerPurchaseMock(body: #"{"success":true}"#) { _ in requestSent.fulfill() }
        installMockingHTTPClient()
        let cleared = expectFlagCleared(bag)

        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")
        )

        wait(for: [requestSent, cleared], timeout: 3.0)
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: otherPlacementKey))
    }

    // MARK: - Lifecycle fences

    func test_layoutClosed_dropsPendingTwoStepForThatExecuteOnly() {
        let impl = RoktInternalImplementation()
        let orch = impl.paymentOrchestratorForTesting
        let closingKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let otherExecuteKey = key(executeId: "other-execute", cartItemId: "cart-b", catalogItemId: "catalog-b")
        seedPayPal(orch, for: closingKey)
        seedCard(orch, for: otherExecuteKey)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))
        drainMainQueue()

        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: closingKey))
        XCTAssertFalse(orch.presentPendingBuiltInPayPalForForwardPayment(for: closingKey) { _ in })
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: otherExecuteKey), "Another placement's checkout is untouched")
        XCTAssertNotNil(orch.beginBuiltInCardForwardPaymentIfReady(for: otherExecuteKey))
    }

    func test_layoutClosed_whileCardPurchaseIsInFlight_stillDeliversTheStepOneResult() {
        let (impl, bag) = makeImplementationAfterStepTwoTap()
        let orch = impl.paymentOrchestratorForTesting
        let itemKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let stepOneResult = expectation(description: "Step-1 completion receives the purchase result")
        orch.unitTest_seedDeferredBuiltInCardForwardPayment(for: itemKey) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            stepOneResult.fulfill()
        }
        registerPurchaseMock(body: #"{"success":true}"#) { _ in }
        installMockingHTTPClient()
        let cleared = expectFlagCleared(bag)

        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")
        )
        // The purchase response is delivered on the main queue, so it cannot land before this close runs.
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))

        XCTAssertTrue(orch.isBuiltInCardForwardPaymentInFlight(), "Closing the layout keeps a purchase already sent")
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: itemKey))
        wait(for: [stepOneResult, cleared], timeout: 3.0)
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: itemKey))
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())
    }

    func test_layoutFailure_dropsPendingTwoStepForThatExecute() {
        let impl = RoktInternalImplementation()
        let orch = impl.paymentOrchestratorForTesting
        let failingKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        seedCard(orch, for: failingKey)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutFailure(layoutId: "layout-1", reason: .invalidSchema))
        drainMainQueue()

        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: failingKey))
        XCTAssertNil(orch.beginBuiltInCardForwardPaymentIfReady(for: failingKey))
    }

    // MARK: - One execute can host several open layouts; a fence is per layout

    func test_layoutClosed_keepsAnotherOpenLayoutsPendingTwoStepUnderTheSameExecute_andItsConfirmStillResumes() {
        let (impl, bag) = makeImplementationAfterStepTwoTap()
        // Two placements open under the one execute; closing one leaves the other's deferred state alone.
        bag.loadedPlacements = 2
        let orch = impl.paymentOrchestratorForTesting
        let closingKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let openKey = key(layoutId: "layout-2", cartItemId: "cart-b", catalogItemId: "catalog-b")
        seedPayPal(orch, for: closingKey)
        let stepOneResult = expectation(description: "The open layout's Step-1 completion receives its purchase result")
        orch.unitTest_seedDeferredBuiltInCardForwardPayment(for: openKey) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            stepOneResult.fulfill()
        }

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))
        drainMainQueue()

        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: closingKey))
        XCTAssertFalse(orch.presentPendingBuiltInPayPalForForwardPayment(for: closingKey) { _ in })
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: openKey), "The other open layout keeps its checkout")
        XCTAssertNotNil(impl.stateManager.getState(id: executeId), "The other open layout's checkout keeps the state")

        registerPurchaseMock(body: #"{"success":true}"#) { _ in }
        installMockingHTTPClient()
        let cleared = expectFlagCleared(bag)
        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(layoutId: "layout-2", cartItemId: "cart-b", catalogItemId: "catalog-b")
        )

        wait(for: [stepOneResult, cleared], timeout: 3.0)
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: openKey))
    }

    func test_layoutFailure_keepsAnotherOpenLayoutsPendingTwoStepUnderTheSameExecute() {
        let impl = RoktInternalImplementation()
        let orch = impl.paymentOrchestratorForTesting
        let failingKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let openKey = key(layoutId: "layout-2", cartItemId: "cart-b", catalogItemId: "catalog-b")
        seedCard(orch, for: failingKey)
        seedCard(orch, for: openKey)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutFailure(layoutId: "layout-1", reason: .invalidSchema))
        drainMainQueue()

        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: failingKey))
        XCTAssertNil(orch.beginBuiltInCardForwardPaymentIfReady(for: failingKey))
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: openKey), "The other open layout keeps its checkout")
        XCTAssertNotNil(orch.beginBuiltInCardForwardPaymentIfReady(for: openKey), "Its confirm still resumes")
    }

    func test_clearSession_dropsEveryPendingTwoStep() {
        let userDefaults = UserDefaults(suiteName: #file)!
        userDefaults.removePersistentDomain(forName: #file)
        defer { userDefaults.removePersistentDomain(forName: #file) }
        let impl = RoktInternalImplementation(
            sessionManager: SessionManager(managedSessions: [], userDefaults: userDefaults)
        )
        impl.txnSessionStore = ScratchTxnStore()
        let orch = impl.paymentOrchestratorForTesting
        let keyA = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let keyB = key(executeId: "other-execute", cartItemId: "cart-b", catalogItemId: "catalog-b")
        seedPayPal(orch, for: keyA)
        seedCard(orch, for: keyB)

        impl.clearSession()
        drainMainQueue()

        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: keyA))
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: keyB))
        XCTAssertFalse(orch.presentPendingBuiltInPayPalForForwardPayment(for: keyA) { _ in })
        XCTAssertNil(orch.beginBuiltInCardForwardPaymentIfReady(for: keyB))
    }

    // MARK: - Initialising again starts a new state keeper; checkouts of the previous one are dropped or fenced

    /// An implementation a test can initialise again without reaching the network or the shared user defaults: the
    /// session and pending-event stores are scratch, and the init request is answered locally with a success.
    private func makeImplementationForReinitialisation(userDefaults: UserDefaults) -> RoktInternalImplementation {
        let impl = RoktInternalImplementation(
            sessionManager: SessionManager(managedSessions: [], userDefaults: userDefaults)
        )
        impl.txnSessionStore = ScratchTxnStore()
        impl.txnPendingEventStore = ScratchPendingEventStore()
        let initHTTPClient = SucceedingInitHTTPClient()
        impl.makeTxnInitServiceOverride = { tagId in
            TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.3.2",
                layoutSchemaVersion: "1.0",
                httpClient: initHTTPClient,
                maxRetries: 0,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
        return impl
    }

    /// Initialising the SDK again replaces the execute state keeper, so a checkout begun before it has nowhere left to
    /// report. Checkouts not yet in flight are dropped without their completion running, as a session clear drops them.
    func test_initWith_dropsEveryPendingTwoStepNotInFlight() {
        let userDefaults = UserDefaults(suiteName: #file)!
        userDefaults.removePersistentDomain(forName: #file)
        defer { userDefaults.removePersistentDomain(forName: #file) }
        let impl = makeImplementationForReinitialisation(userDefaults: userDefaults)
        let orch = impl.paymentOrchestratorForTesting
        let keyA = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let keyB = key(executeId: "other-execute", cartItemId: "cart-b", catalogItemId: "catalog-b")
        seedPayPal(orch, for: keyA)
        seedCard(orch, for: keyB)
        impl.stateManager.addState(id: executeId, state: ExecuteStateBag(uxHelper: nil, onRoktEvent: nil))

        impl.initWith(roktTagId: forwardPaymentTestTagId, mParticleKitDetails: nil)
        drainMainQueue()

        XCTAssertNil(impl.stateManager.getState(id: executeId), "Initialising again starts a new state keeper")
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: keyA))
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: keyB))
        XCTAssertFalse(orch.presentPendingBuiltInPayPalForForwardPayment(for: keyA) { _ in })
        XCTAssertNil(orch.beginBuiltInCardForwardPaymentIfReady(for: keyB))
        waitUntil { impl.isInitialized }
    }

    /// A card purchase already sent when the SDK is initialised again is fenced, not dropped: its result still reaches
    /// its Step-1 completion, and once it has, nothing of it is left. A PayPal checkout still waiting for its confirm is
    /// dropped, so a later confirm or return link for it finds nothing to resume and its completion never runs.
    func test_initWith_whileCardPurchaseIsInFlight_stillDeliversTheStepOneResult_andDropsAPendingPayPalCheckout() {
        let userDefaults = UserDefaults(suiteName: #file)!
        userDefaults.removePersistentDomain(forName: #file)
        defer { userDefaults.removePersistentDomain(forName: #file) }
        let impl = makeImplementationForReinitialisation(userDefaults: userDefaults)
        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        bag.loadedPlacements = 1
        bag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: executeId, state: bag)
        let orch = impl.paymentOrchestratorForTesting
        let cardKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let payPalKey = key(cartItemId: "cart-b", catalogItemId: "catalog-b")
        let stepOneResult = expectation(description: "Step-1 completion receives the purchase result")
        orch.unitTest_seedDeferredBuiltInCardForwardPayment(for: cardKey) { result in
            XCTAssertEqual(result.outcome, .succeeded)
            stepOneResult.fulfill()
        }
        seedPayPal(orch, for: payPalKey)
        registerPurchaseMock(body: #"{"success":true}"#) { _ in }
        installMockingHTTPClient()

        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")
        )
        // The purchase response is delivered on the main queue, so it cannot land before this initialisation runs.
        impl.initWith(roktTagId: forwardPaymentTestTagId, mParticleKitDetails: nil)

        XCTAssertTrue(orch.isBuiltInCardForwardPaymentInFlight(), "Initialising again keeps a purchase already sent")
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: cardKey))
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: payPalKey), "A checkout not yet in flight is dropped")
        wait(for: [stepOneResult], timeout: 3.0)
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: cardKey))
        XCTAssertFalse(orch.isBuiltInCardForwardPaymentInFlight())

        // A confirm or a return link for the dropped PayPal checkout finds nothing to resume.
        XCTAssertFalse(orch.presentPendingBuiltInPayPalForForwardPayment(for: payPalKey) { _ in })
        XCTAssertFalse(orch.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_MOCK")!))
        drainMainQueue()
        XCTAssertNil(impl.stateManager.getState(id: executeId), "The new state keeper holds nothing of the previous execute")
        waitUntil { impl.isInitialized }
    }

    // MARK: - An execute's state outlives its placements while a checkout of that execute is still outstanding

    private func makeDevicePayEvent(
        layoutId: String,
        cartItemId: String,
        catalogItemId: String
    ) -> RoktUXEvent.CartItemDevicePay {
        RoktUXEvent.CartItemDevicePay(
            layoutId: layoutId,
            name: "Test item",
            cartItemId: cartItemId,
            catalogItemId: catalogItemId,
            currency: "USD",
            description: "desc",
            linkedProductId: nil,
            providerData: "provider",
            quantity: 1,
            totalPrice: 9.99,
            unitPrice: 9.99,
            paymentProvider: .paypal,
            transactionData: nil
        )
    }

    /// A Step-1 response carrying a PayPal approval URL and `orderId`, so the item's confirm presents the approval sheet.
    private func payPalInitializePurchaseResponse(orderId: String) -> InitializePurchaseResponse {
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
                approvalUrl: "https://www.paypal.com/checkoutnow?token=\(orderId)"
            )
        )
    }

    /// Two items of one execute start built-in checkouts. The first finishes, then both placements close while the
    /// second item's PayPal approval sheet is still up. The execute's state must outlive the unload so the second
    /// item's return still reaches the partner and the layout, and must go once that item has finished.
    func test_layoutClosed_whileASecondItemsPayPalSheetIsUp_stillDeliversThatItemsResult() {
        let impl = RoktInternalImplementation()
        let presenter = HoldingPayPalApprovalPresenter()
        impl.paymentOrchestratorForTesting = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: presenter
        )
        defer { PaymentOrchestratorAPIHelperSpy.reset() }
        let orch = impl.paymentOrchestratorForTesting
        let uxHelper = FinalizeRecordingRoktUX()
        var partnerEvents: [RoktEvent] = []
        let bag = ExecuteStateBag(uxHelper: uxHelper) { partnerEvents.append($0) }
        bag.loadedPlacements = 2
        impl.stateManager.addState(id: executeId, state: bag)
        // Both items were tapped; the renderer reports each start through the execute's one flag.
        impl.stateManager.initiateInstantPurchase(id: executeId)
        impl.stateManager.initiateInstantPurchase(id: executeId)
        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId

        // Item A (card, first placement) confirms and finishes, which clears the flag.
        let itemAResult = expectation(description: "Item A's Step-1 completion receives its result")
        orch.unitTest_seedDeferredBuiltInCardForwardPayment(for: key(cartItemId: "cart-a", catalogItemId: "catalog-a")) {
            XCTAssertEqual($0.outcome, .succeeded)
            itemAResult.fulfill()
        }
        registerPurchaseMock(body: #"{"success":true}"#) { _ in }
        installMockingHTTPClient()
        let cleared = expectFlagCleared(bag)
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")
        )
        wait(for: [itemAResult, cleared], timeout: 3.0)

        // Item B (PayPal, second placement) runs Step-1, then its confirm puts the approval sheet up.
        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = payPalInitializePurchaseResponse(orderId: "ORDER_B")
        // Held strongly: the pending checkout only keeps a weak reference to the screen it presents from.
        let presentingViewController = UIViewController()
        let itemBDevicePay = makeDevicePayEvent(layoutId: "layout-2", cartItemId: "cart-b", catalogItemId: "catalog-b")
        let itemBSession = BuiltInTwoStepDevicePaySession(
            executeId: executeId,
            layoutId: "layout-2",
            catalogItemId: "catalog-b"
        ) { _, _, _ in }
        orch.processPayment(
            method: .paypal,
            item: PaymentItem(id: "catalog-b", name: "Test item", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: nil
            ),
            cartItemId: "cart-b",
            from: presentingViewController,
            builtInPayPalDevicePaySession: itemBSession
        ) { result in
            impl.handleDevicePayPaymentCompletion(executeId: self.executeId, event: itemBDevicePay, result: result)
        }
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(layoutId: "layout-2", cartItemId: "cart-b", catalogItemId: "catalog-b")
        )
        drainMainQueue()
        XCTAssertEqual(presenter.presentCallCount, 1, "Item B's approval sheet is up")

        // Both placements close while that sheet is still up.
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-2"))
        XCTAssertEqual(bag.loadedPlacements, 0)
        XCTAssertNotNil(
            impl.stateManager.getState(id: executeId),
            "The execute's state is kept while item B's checkout can still report back"
        )

        // The buyer approves, and the return link completes item B.
        XCTAssertTrue(orch.handleURLCallback(with: URL(string: "myapp://paypal/success?token=ORDER_B")!))
        drainMainQueue()

        let itemBPurchase = partnerEvents.compactMap { $0 as? RoktEvent.CartItemInstantPurchase }.first
        XCTAssertEqual(itemBPurchase?.catalogItemId, "catalog-b", "The partner hears item B's result")
        XCTAssertTrue(
            uxHelper.finalizedCalls.contains { $0.layoutId == "layout-2" && $0.catalogItemId == "catalog-b" && $0.success },
            "The layout hears item B's result from its Step-1 completion"
        )
        XCTAssertTrue(
            uxHelper.forwardFinalizedCalls.contains {
                $0.layoutId == "layout-2" && $0.catalogItemId == "catalog-b" && $0.success
            },
            "The layout hears item B's result from its Step-2 return"
        )
        XCTAssertNil(impl.stateManager.getState(id: executeId), "Once item B has finished, nothing holds the state")
    }

    // MARK: - A checkout dropped by a fence releases the execute's state, which no finish will ever release

    /// One PayPal checkout waits for its confirm when its placement closes. The close drops the checkout, and the
    /// execute's state, which the tap's instant-purchase flag would otherwise keep for the life of the state keeper,
    /// goes with it once the placement has unloaded.
    func test_layoutClosed_droppingTheOnlyCheckoutOfTheExecute_releasesTheExecutesState() {
        let (impl, bag) = makeImplementationAfterStepTwoTap()
        let orch = impl.paymentOrchestratorForTesting
        let itemKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        seedPayPal(orch, for: itemKey)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))
        XCTAssertEqual(bag.loadedPlacements, 0)
        drainMainQueue()

        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: itemKey))
        XCTAssertFalse(bag.instantPurchaseInitiated, "A dropped checkout can never finish, so its flag is cleared")
        XCTAssertNil(impl.stateManager.getState(id: executeId), "Nothing holds the state once its checkout is dropped")
    }

    /// A session clear drops a checkout waiting for its confirm. With every placement already unloaded, the execute's
    /// state goes at once; with a placement still up, the state stays until that placement unloads.
    func test_clearSession_droppingTheOnlyCheckoutOfAnExecute_releasesItsStateOnceNothingElseHoldsIt() {
        let userDefaults = UserDefaults(suiteName: #file)!
        userDefaults.removePersistentDomain(forName: #file)
        defer { userDefaults.removePersistentDomain(forName: #file) }
        let impl = RoktInternalImplementation(
            sessionManager: SessionManager(managedSessions: [], userDefaults: userDefaults)
        )
        impl.txnSessionStore = ScratchTxnStore()
        let orch = impl.paymentOrchestratorForTesting
        let unloadedBag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        unloadedBag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: executeId, state: unloadedBag)
        let showingBag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        showingBag.loadedPlacements = 1
        showingBag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: "showing-execute", state: showingBag)
        seedPayPal(orch, for: key(cartItemId: "cart-a", catalogItemId: "catalog-a"))
        seedPayPal(orch, for: key(executeId: "showing-execute", cartItemId: "cart-b", catalogItemId: "catalog-b"))

        impl.clearSession()
        drainMainQueue()

        XCTAssertNil(impl.stateManager.getState(id: executeId), "The dropped checkout was all that held the unloaded state")
        XCTAssertNotNil(impl.stateManager.getState(id: "showing-execute"), "A placement still up keeps its state")
        XCTAssertFalse(showingBag.instantPurchaseInitiated, "The dropped checkout no longer holds it")

        impl.callOnRoktUXEvent("showing-execute", uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))
        drainMainQueue()
        XCTAssertNil(impl.stateManager.getState(id: "showing-execute"), "The state goes with its last placement")
    }

    /// A PayPal approval sheet is up when its placement closes, and the buyer then cancels. The checkout is dropped
    /// rather than re-queued, nothing is owed to the partner or the layout for it, and the execute's state goes with it.
    func test_layoutClosed_whileItsPayPalSheetIsUp_thenCancelled_releasesTheExecutesState() {
        let impl = RoktInternalImplementation()
        let presenter = HoldingPayPalApprovalPresenter()
        impl.paymentOrchestratorForTesting = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: presenter
        )
        defer { PaymentOrchestratorAPIHelperSpy.reset() }
        let orch = impl.paymentOrchestratorForTesting
        var partnerEvents: [RoktEvent] = []
        let bag = ExecuteStateBag(uxHelper: nil) { partnerEvents.append($0) }
        bag.loadedPlacements = 1
        impl.stateManager.addState(id: executeId, state: bag)
        impl.stateManager.initiateInstantPurchase(id: executeId)
        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId

        PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = payPalInitializePurchaseResponse(orderId: "ORDER_A")
        // Held strongly: the pending checkout only keeps a weak reference to the screen it presents from.
        let presentingViewController = UIViewController()
        orch.processPayment(
            method: .paypal,
            item: PaymentItem(id: "catalog-a", name: "Test item", amount: 1, currency: "USD"),
            context: PaymentContext(
                billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                returnURL: "myapp://paypal/success",
                cancelURL: "myapp://paypal/cancel"
            ),
            cartItemId: "cart-a",
            from: presentingViewController,
            builtInPayPalDevicePaySession: BuiltInTwoStepDevicePaySession(
                executeId: executeId,
                layoutId: "layout-1",
                catalogItemId: "catalog-a"
            ) { _, _, _ in }
        ) { result in
            XCTFail("A checkout dropped after its placement closed reports nothing, got \(result.outcome)")
        }
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")
        )
        drainMainQueue()
        XCTAssertEqual(presenter.presentCallCount, 1, "The approval sheet is up")

        // The placement closes while the sheet is up; the state stays until the sheet reports back.
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))
        drainMainQueue()
        XCTAssertEqual(bag.loadedPlacements, 0)
        XCTAssertNotNil(impl.stateManager.getState(id: executeId), "The state is kept while the sheet can still report back")

        // The buyer cancels: with the placement gone, the checkout is dropped and nothing is left to hold the state.
        XCTAssertTrue(orch.handleURLCallback(with: URL(string: "myapp://paypal/cancel?token=ORDER_A")!))
        drainMainQueue()

        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: key(cartItemId: "cart-a", catalogItemId: "catalog-a")))
        // The close itself reached the partner while the state was still there; the dropped checkout adds nothing.
        XCTAssertEqual(partnerEvents.count, 1, "The partner hears the close, and nothing else")
        XCTAssertTrue(
            partnerEvents.allSatisfy { $0 is RoktEvent.PlacementClosed },
            "Beyond the close itself, nothing is owed to the partner for a placement that is gone"
        )
        XCTAssertNil(impl.stateManager.getState(id: executeId), "Nothing holds the state once its checkout is dropped")
    }

    /// A PayPal approval sheet is up when its placement closes; the host then tears the sheet down without a cancel or
    /// a return, and a later approval for another execute presents in its place and releases the checkout. The mark
    /// left behind is pruned by the next confirm, and the execute it belonged to, which nothing else holds, goes with it.
    func test_layoutClosed_whileItsPayPalSheetIsUp_thenTheSheetIsTornDownAndItsCheckoutReleased_releasesTheExecutesState() {
        let impl = RoktInternalImplementation()
        let presenter = HoldingPayPalApprovalPresenter()
        impl.paymentOrchestratorForTesting = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: presenter
        )
        defer { PaymentOrchestratorAPIHelperSpy.reset() }
        let orch = impl.paymentOrchestratorForTesting
        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        bag.loadedPlacements = 1
        impl.stateManager.addState(id: executeId, state: bag)
        impl.stateManager.initiateInstantPurchase(id: executeId)
        let otherBag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        otherBag.loadedPlacements = 1
        impl.stateManager.addState(id: "other-execute", state: otherBag)
        // Held strongly: the pending checkouts only keep a weak reference to the screen they present from.
        let presentingViewController = UIViewController()
        func startPayPalStepOne(
            executeId: String,
            layoutId: String,
            cartItemId: String,
            catalogItemId: String,
            orderId: String
        ) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = payPalInitializePurchaseResponse(orderId: orderId)
            orch.processPayment(
                method: .paypal,
                item: PaymentItem(id: catalogItemId, name: "Test item", amount: 1, currency: "USD"),
                context: PaymentContext(
                    billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                    returnURL: "myapp://paypal/success",
                    cancelURL: "myapp://paypal/cancel"
                ),
                cartItemId: cartItemId,
                from: presentingViewController,
                builtInPayPalDevicePaySession: BuiltInTwoStepDevicePaySession(
                    executeId: executeId,
                    layoutId: layoutId,
                    catalogItemId: catalogItemId
                ) { _, _, _ in }
            ) { result in
                XCTFail("Neither approval reports back in this test, got \(result.outcome)")
            }
        }
        startPayPalStepOne(
            executeId: executeId, layoutId: "layout-1", cartItemId: "cart-a", catalogItemId: "catalog-a", orderId: "ORDER_A"
        )
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")
        )
        drainMainQueue()
        XCTAssertEqual(presenter.presentCallCount, 1, "The approval sheet is up")

        // The placement closes while the sheet is up, and the host then tears the sheet down without reporting back.
        // The checkout itself is still held, so its mark still counts and the state is kept.
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "layout-1"))
        presenter.presentedSheets.first?.tearDown()
        drainMainQueue()
        XCTAssertEqual(bag.loadedPlacements, 0)
        XCTAssertNotNil(impl.stateManager.getState(id: executeId), "The state is kept while the checkout can still report back")

        // Another execute's item is confirmed; its approval presents in place of the sheet that is gone, and the first
        // checkout, held by nothing else, is released. Its mark stays until a later pass prunes it, and so does the state.
        startPayPalStepOne(
            executeId: "other-execute",
            layoutId: "layout-2",
            cartItemId: "cart-b",
            catalogItemId: "catalog-b",
            orderId: "ORDER_B"
        )
        let otherConfirm = makeForwardPaymentEvent(layoutId: "layout-2", cartItemId: "cart-b", catalogItemId: "catalog-b")
        impl.handleForwardPayment(executeId: "other-execute", event: otherConfirm)
        drainMainQueue()
        XCTAssertEqual(presenter.presentCallCount, 2, "The other execute's approval sheet is presented")
        XCTAssertNotNil(impl.stateManager.getState(id: executeId), "The mark is pruned only on a later pass")

        // A repeated confirm for the other item has nothing to start, but prunes the first mark and reports the first
        // execute; nothing else holds that execute's state, so the state goes and the tap's flag with it.
        impl.handleForwardPayment(executeId: "other-execute", event: otherConfirm)
        drainMainQueue()
        XCTAssertEqual(presenter.presentCallCount, 2, "A repeated confirm for an approval already up presents nothing")
        XCTAssertFalse(bag.instantPurchaseInitiated, "An approval that never reports back can never clear the flag itself")
        XCTAssertNil(impl.stateManager.getState(id: executeId), "Nothing holds the state once the abandoned mark is pruned")
        XCTAssertNotNil(impl.stateManager.getState(id: "other-execute"), "The approval still up keeps its own execute")
    }

    // MARK: - A confirm during a repeated Step-1 for the item belongs to PayPal and starts nothing

    /// Step-1 runs again for an item whose PayPal checkout is already on offer. Until the new request answers, a
    /// confirm for the item neither presents the superseded order nor falls through to a card purchase; once it has
    /// answered, exactly one checkout is on offer and the next confirm presents it.
    func test_handleForwardPayment_whileAPayPalStepOneIsOutForTheItem_startsNoPurchaseAndWaitsForTheNewCheckout() {
        let impl = RoktInternalImplementation()
        let presenter = HoldingPayPalApprovalPresenter()
        impl.paymentOrchestratorForTesting = PaymentOrchestrator(
            apiHelper: PaymentOrchestratorAPIHelperSpy.self,
            payPalApprovalPresenter: presenter
        )
        defer { PaymentOrchestratorAPIHelperSpy.reset() }
        let orch = impl.paymentOrchestratorForTesting
        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        bag.loadedPlacements = 1
        bag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: executeId, state: bag)
        registerPurchaseMock(body: #"{"success":true}"#) { _ in
            XCTFail("A confirm for an item whose PayPal checkout is being prepared must not run a cart purchase")
        }
        installMockingHTTPClient()
        Rokt.shared.roktImplementation.roktTagId = forwardPaymentTestTagId
        // Held strongly: the pending checkout only keeps a weak reference to the screen it presents from.
        let presentingViewController = UIViewController()
        var confirmationCount = 0
        func startStepOne(orderId: String) {
            PaymentOrchestratorAPIHelperSpy.initializePurchaseResponse = payPalInitializePurchaseResponse(orderId: orderId)
            orch.processPayment(
                method: .paypal,
                item: PaymentItem(id: "catalog-a", name: "Test item", amount: 1, currency: "USD"),
                context: PaymentContext(
                    billingAddress: ContactAddress(name: "A", email: "a@b.com"),
                    returnURL: "myapp://paypal/success",
                    cancelURL: nil
                ),
                cartItemId: "cart-a",
                from: presentingViewController,
                builtInPayPalDevicePaySession: BuiltInTwoStepDevicePaySession(
                    executeId: executeId,
                    layoutId: "layout-1",
                    catalogItemId: "catalog-a"
                ) { _, _, _ in confirmationCount += 1 }
            ) { _ in }
        }
        let itemKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let confirm = makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")
        startStepOne(orderId: "ORDER_1")
        XCTAssertEqual(confirmationCount, 1)
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: itemKey))

        // Step-1 runs again for the item and its response is held back; a confirm arrives in the meantime.
        PaymentOrchestratorAPIHelperSpy.holdInitializePurchaseResponse = true
        startStepOne(orderId: "ORDER_2")
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: itemKey), "The superseded checkout is off offer at once")
        impl.handleForwardPayment(executeId: executeId, event: confirm)
        let settled = expectation(description: "a cart purchase would have been sent by now")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)
        XCTAssertEqual(presenter.presentCallCount, 0, "The superseded order is never presented")
        XCTAssertTrue(bag.instantPurchaseInitiated, "No purchase ran, so nothing finalized the item")

        // The new request answers: one checkout is on offer, and the next confirm presents it.
        PaymentOrchestratorAPIHelperSpy.releaseHeldInitializePurchase()
        XCTAssertEqual(confirmationCount, 2, "The confirm button is shown again for the new checkout")
        XCTAssertTrue(orch.unitTest_hasPendingBuiltInTwoStep(for: itemKey))
        impl.handleForwardPayment(executeId: executeId, event: confirm)
        drainMainQueue()
        XCTAssertEqual(presenter.presentCallCount, 1)
        XCTAssertFalse(orch.unitTest_hasPendingBuiltInTwoStep(for: itemKey), "The one checkout was taken for its approval")
    }

    // MARK: - A confirm delivered off the main thread is handled on it

    /// Seeds a pending PayPal Step-1 whose confirm presents its approval sheet, so its completion may run later.
    private func seedPayPalForPresentation(_ orch: PaymentOrchestrator, for key: BuiltInTwoStepCheckoutKey) {
        orch.unitTest_seedDeferredBuiltInPayPalForwardPayment(
            for: key,
            approvalURL: URL(string: "https://www.paypal.com/checkoutnow?token=MOCK")!,
            returnURLString: "myapp://paypal/success",
            orderId: "ORDER_MOCK"
        ) { _ in }
    }

    /// The one-approval gate reads whether an approval sheet's view is in a window, so a confirm that reaches the
    /// implementation off the main thread is handled on it, with the same outcome as one that arrived there. A confirm
    /// already on the main thread is handled before the call returns, which the tests above rely on.
    func test_handleForwardPayment_offTheMainThread_isHandledOnTheMainThreadWithTheSameOutcome() {
        let itemKey = key(cartItemId: "cart-a", catalogItemId: "catalog-a")
        let event = makeForwardPaymentEvent(cartItemId: "cart-a", catalogItemId: "catalog-a")

        // On the main thread the pending checkout is taken before the call returns.
        let onMainImpl = RoktInternalImplementation()
        let onMainPresenter = HoldingPayPalApprovalPresenter()
        onMainImpl.paymentOrchestratorForTesting = PaymentOrchestrator(payPalApprovalPresenter: onMainPresenter)
        let onMainOrch = onMainImpl.paymentOrchestratorForTesting
        seedPayPalForPresentation(onMainOrch, for: itemKey)
        onMainImpl.handleForwardPayment(executeId: executeId, event: event)
        XCTAssertFalse(onMainOrch.unitTest_hasPendingBuiltInTwoStep(for: itemKey), "Handled before the call returned")
        drainMainQueue()
        let presentedFromTheMainThread = onMainPresenter.presentCallCount

        // Off the main thread nothing is read until the main thread runs. The main thread is held here until the call
        // has returned, so the hop cannot run first.
        PaymentOrchestrator.resetBuiltInTwoStepDeferredStateForTesting()
        let offMainImpl = RoktInternalImplementation()
        let offMainPresenter = HoldingPayPalApprovalPresenter()
        offMainImpl.paymentOrchestratorForTesting = PaymentOrchestrator(payPalApprovalPresenter: offMainPresenter)
        let offMainOrch = offMainImpl.paymentOrchestratorForTesting
        seedPayPalForPresentation(offMainOrch, for: itemKey)
        let returned = DispatchSemaphore(value: 0)
        var pendingWhenTheCallReturned = false
        var approvalsStartedWhenTheCallReturned = -1
        DispatchQueue.global(qos: .userInitiated).async {
            offMainImpl.handleForwardPayment(executeId: self.executeId, event: event)
            pendingWhenTheCallReturned = offMainOrch.unitTest_hasPendingBuiltInTwoStep(for: itemKey)
            approvalsStartedWhenTheCallReturned = offMainOrch.unitTest_presentedBuiltInPayPalCount()
            returned.signal()
        }
        XCTAssertEqual(returned.wait(timeout: .now() + 3), .success, "The call returns without waiting on the main thread")
        XCTAssertTrue(pendingWhenTheCallReturned, "The pending checkout is not read off the main thread")
        XCTAssertEqual(approvalsStartedWhenTheCallReturned, 0, "No approval is started off the main thread")

        drainMainQueue()
        XCTAssertFalse(offMainOrch.unitTest_hasPendingBuiltInTwoStep(for: itemKey), "Handled once the main thread ran")
        XCTAssertEqual(offMainPresenter.presentCallCount, presentedFromTheMainThread, "Same outcome as on the main thread")
    }
}

/// Records the layout finalize calls: the device-pay ones a Step-1 completion makes, and the forward-payment ones a
/// Step-2 return makes. The forward-payment override does not call through, so no layout needs to be loaded.
private final class FinalizeRecordingRoktUX: RoktUX {
    struct FinalizedCall {
        let layoutId: String
        let catalogItemId: String
        let success: Bool
    }

    struct ForwardFinalizedCall {
        let layoutId: String
        let catalogItemId: String
        let success: Bool
        let failureReason: String?
    }

    private(set) var finalizedCalls: [FinalizedCall] = []
    private(set) var forwardFinalizedCalls: [ForwardFinalizedCall] = []

    override func devicePayFinalized(layoutId: String, catalogItemId: String, success: Bool) {
        finalizedCalls.append(FinalizedCall(layoutId: layoutId, catalogItemId: catalogItemId, success: success))
        super.devicePayFinalized(layoutId: layoutId, catalogItemId: catalogItemId, success: success)
    }

    override func forwardPaymentFinalized(
        layoutId: String,
        catalogItemId: String,
        success: Bool,
        failureReason: String?
    ) {
        forwardFinalizedCalls.append(ForwardFinalizedCall(
            layoutId: layoutId,
            catalogItemId: catalogItemId,
            success: success,
            failureReason: failureReason
        ))
    }
}

/// Answers every request with a successful init response, so a test can initialise the SDK without a network.
private final class SucceedingInitHTTPClient: HTTPClientAdapter {
    private static let initResponseBody = Data(
        """
        {
          "session_id": "sess-1",
          "session_token": { "token": "jwt", "expires_at": 32503680000000 },
          "feature_flags": {},
          "fonts": []
        }
        """.utf8
    )

    func updateTimeout(timeout: Double) {}

    @discardableResult
    func startRequestWith(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters?,
        parameterArray: RoktHTTPParameterArray?,
        headers: RoktHTTPHeaders?,
        onRequestStart: (() -> Void)?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktHTTPRequestResult) -> Void)?
    ) -> URLRequest? {
        let url = URL(string: urlAddress) ?? URL(string: "https://apps.rokt.com")!
        let result = RoktHTTPRequestResult(
            httpURLResponse: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            responseData: Self.initResponseBody,
            responseError: nil,
            jsonSerialisedResponseData: .success(NSNull())
        )
        completionQueue.async { completionHandler?(result) }
        return nil
    }

    func downloadFile(
        source urlAddress: String,
        destinationURL: URL,
        options: [RoktDownloadOptions],
        parameters: RoktHTTPParameters?,
        headers: RoktHTTPHeaders?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktDownloadResult) -> Void)?
    ) {}
}

/// Holds no pending event batches, so initialising again in a test replays nothing.
private final class ScratchPendingEventStore: TxnPendingEventStoring {
    func persist(events: [TxnEvent], sessionId: String?) {}
    func drainValid() -> [TxnPendingEventBatch] { [] }
}
