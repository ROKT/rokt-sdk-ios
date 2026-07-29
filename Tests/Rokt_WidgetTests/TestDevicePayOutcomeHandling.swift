import XCTest
import RoktContracts
@testable import Rokt_Widget
@testable internal import RoktUXHelper

/// Verifies `handleDevicePayPaymentCompletion` routes extension-routed device pay
/// (e.g. Stripe card) outcomes to the correct partner events and UX callbacks.
final class TestDevicePayOutcomeHandling: XCTestCase {

    private let executeId = "test-execute-id"
    private let layoutId = "layout-1"
    private let catalogItemId = "catalog-1"
    private let cartItemId = "v1:cart-1:canal"

    // MARK: - Helpers

    private func makeDevicePayEvent() -> RoktUXEvent.CartItemDevicePay {
        RoktUXEvent.CartItemDevicePay(
            layoutId: layoutId,
            name: "Test item",
            cartItemId: cartItemId,
            catalogItemId: catalogItemId,
            currency: "USD",
            description: "desc",
            linkedProductId: nil,
            providerData: "{}",
            quantity: 1,
            totalPrice: 9.99,
            unitPrice: 9.99,
            paymentProvider: .stripe,
            transactionData: nil
        )
    }

    private func makeImplementation(
        uxHelper: SpyRoktUX = SpyRoktUX(),
        onEvent: @escaping (RoktEvent) -> Void
    ) -> (RoktInternalImplementation, SpyRoktUX) {
        let impl = RoktInternalImplementation()
        let bag = ExecuteStateBag(uxHelper: uxHelper, onRoktEvent: onEvent)
        bag.loadedPlacements = 1
        impl.stateManager.addState(id: executeId, state: bag)
        return (impl, uxHelper)
    }

    // MARK: - Tests

    func test_devicePayCanceled_callsRetryWithoutFailureOrFinalize() {
        var events: [RoktEvent] = []
        let (impl, uxHelper) = makeImplementation { events.append($0) }

        impl.handleDevicePayPaymentCompletion(
            executeId: executeId,
            event: makeDevicePayEvent(),
            result: .canceled
        )

        XCTAssertEqual(uxHelper.retryCalls.count, 1)
        XCTAssertEqual(uxHelper.retryCalls.first?.layoutId, layoutId)
        XCTAssertEqual(uxHelper.retryCalls.first?.catalogItemId, catalogItemId)
        XCTAssertTrue(uxHelper.finalizedCalls.isEmpty)
        XCTAssertTrue(events.isEmpty)
    }

    func test_devicePaySucceeded_emitsPurchaseAndFinalizesSuccess() {
        var events: [RoktEvent] = []
        let (impl, uxHelper) = makeImplementation { events.append($0) }

        impl.handleDevicePayPaymentCompletion(
            executeId: executeId,
            event: makeDevicePayEvent(),
            result: .succeeded(transactionId: "txn-1")
        )

        XCTAssertTrue(events.contains { $0 is RoktEvent.CartItemInstantPurchase })
        XCTAssertFalse(events.contains { $0 is RoktEvent.CartItemInstantPurchaseFailure })
        XCTAssertEqual(uxHelper.finalizedCalls.count, 1)
        XCTAssertEqual(uxHelper.finalizedCalls.first?.success, true)
        XCTAssertTrue(uxHelper.retryCalls.isEmpty)
    }

    func test_devicePayFailed_emitsFailureWithErrorMessageAndFinalizesFailure() {
        var events: [RoktEvent] = []
        let (impl, uxHelper) = makeImplementation { events.append($0) }

        impl.handleDevicePayPaymentCompletion(
            executeId: executeId,
            event: makeDevicePayEvent(),
            result: .failed(error: "Card declined")
        )

        let failure = events.compactMap { $0 as? RoktEvent.CartItemInstantPurchaseFailure }.first
        XCTAssertEqual(failure?.error, "Card declined")
        XCTAssertFalse(events.contains { $0 is RoktEvent.CartItemInstantPurchase })
        XCTAssertEqual(uxHelper.finalizedCalls.count, 1)
        XCTAssertEqual(uxHelper.finalizedCalls.first?.success, false)
        XCTAssertTrue(uxHelper.retryCalls.isEmpty)
    }
}

// MARK: - Test doubles

private final class SpyRoktUX: RoktUX {
    struct FinalizedCall {
        let layoutId: String
        let catalogItemId: String
        let success: Bool
    }

    struct RetryCall {
        let layoutId: String
        let catalogItemId: String
    }

    private(set) var finalizedCalls: [FinalizedCall] = []
    private(set) var retryCalls: [RetryCall] = []

    override func devicePayFinalized(layoutId: String, catalogItemId: String, success: Bool) {
        finalizedCalls.append(FinalizedCall(layoutId: layoutId, catalogItemId: catalogItemId, success: success))
        super.devicePayFinalized(layoutId: layoutId, catalogItemId: catalogItemId, success: success)
    }

    override func devicePayRetry(layoutId: String, catalogItemId: String) {
        retryCalls.append(RetryCall(layoutId: layoutId, catalogItemId: catalogItemId))
        super.devicePayRetry(layoutId: layoutId, catalogItemId: catalogItemId)
    }
}
