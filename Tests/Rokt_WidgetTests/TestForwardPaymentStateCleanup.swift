import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper
import Mocker

/// With ux-helper 0.10.4 the forward-payment flow emits
/// `SignalCartItemInstantPurchaseInitiated` on tap (setting
/// `instantPurchaseInitiated = true` on the state bag) but no longer emits
/// Success/Failure events, so nothing in the event pipeline clears the flag.
/// `forwardPaymentFinalized` must clear it directly; otherwise a later
/// `Rokt.purchaseFinalized(...)` could match the stale state via
/// `find(where: \.instantPurchaseInitiated)` and finalize the wrong flow.
final class TestForwardPaymentStateCleanup: XCTestCase {

    private let purchaseURL = URL(string: "https://mobile-api.rokt.com/v1/cart/purchase")!
    private let executeId = "test-execute-id"

    private var originalTagId: String?

    override func setUp() {
        super.setUp()
        Rokt.setEnvironment(environment: .Prod)
        originalTagId = Rokt.shared.roktImplementation.roktTagId
        Rokt.shared.roktImplementation.roktTagId = "test-tag-id"
    }

    override func tearDown() {
        Rokt.shared.roktImplementation.roktTagId = originalTagId
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeEvent() -> RoktUXEvent.CartItemForwardPayment {
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

    /// Seeds a fresh `RoktInternalImplementation` with a state bag whose
    /// `instantPurchaseInitiated` flag is already `true` (as if the tap
    /// had already been processed). `loadedPlacements` is set to 1 so the
    /// bag is not auto-removed by `checkRemoveState` when the flag is
    /// cleared — that lets the test assert on the flag after completion.
    private func makeImplementation() -> (RoktInternalImplementation, ExecuteStateBag) {
        let impl = RoktInternalImplementation()
        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        bag.loadedPlacements = 1
        bag.instantPurchaseInitiated = true
        impl.stateManager.addState(id: executeId, state: bag)
        return (impl, bag)
    }

    private func registerPurchaseMock(statusCode: Int, body: String) {
        var mock = Mock(
            url: purchaseURL,
            dataType: .json,
            statusCode: statusCode,
            data: [.post: Data(body.utf8)]
        )
        mock.register()
    }

    private func installMockingHTTPClient() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)
    }

    /// Returns an expectation that fulfills once `bag.instantPurchaseInitiated`
    /// flips to `false`. We poll on the main queue because the clear happens
    /// inside the async network callback — a fixed sleep would be flakier and
    /// slower than a short poll.
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

    // MARK: - Tests

    func test_forwardPaymentFinalized_clearsInstantPurchaseState_onSuccess() {
        let (impl, bag) = makeImplementation()

        registerPurchaseMock(statusCode: 200, body: "{\"success\":true}")
        installMockingHTTPClient()

        let cleared = expectFlagCleared(bag)

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [cleared], timeout: 2.0)
        XCTAssertFalse(bag.instantPurchaseInitiated)
    }

    func test_forwardPaymentFinalized_clearsInstantPurchaseState_onBusinessFailure() {
        let (impl, bag) = makeImplementation()

        registerPurchaseMock(statusCode: 200, body: "{\"success\":false,\"reason\":\"declined\"}")
        installMockingHTTPClient()

        let cleared = expectFlagCleared(bag)

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [cleared], timeout: 2.0)
        XCTAssertFalse(bag.instantPurchaseInitiated)
    }

    func test_forwardPaymentFinalized_clearsInstantPurchaseState_onNetworkFailure() {
        let (impl, bag) = makeImplementation()

        registerPurchaseMock(statusCode: 500, body: "{}")
        installMockingHTTPClient()

        let cleared = expectFlagCleared(bag)

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [cleared], timeout: 5.0)
        XCTAssertFalse(bag.instantPurchaseInitiated)
    }

    func test_forwardPaymentFinalized_clearsInstantPurchaseState_onMissingPriceEarlyReturn() {
        let (impl, bag) = makeImplementation()

        // No network mock — the missing-price branch bails before
        // `/v1/cart/purchase` is called but still routes through
        // `forwardPaymentFinalized`, which must clear the flag.
        let cleared = expectFlagCleared(bag)

        let eventMissingPrice = RoktUXEvent.CartItemForwardPayment(
            layoutId: "layout-1",
            name: "Test item",
            cartItemId: "cart-1",
            catalogItemId: "catalog-1",
            currency: "USD",
            description: "desc",
            linkedProductId: nil,
            providerData: "provider",
            quantity: 1,
            totalPrice: nil,
            unitPrice: nil,
            transactionData: nil
        )
        impl.handleForwardPayment(executeId: executeId, event: eventMissingPrice)

        wait(for: [cleared], timeout: 1.0)
        XCTAssertFalse(bag.instantPurchaseInitiated)
    }
}
