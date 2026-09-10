import UIKit
import XCTest
@testable import Rokt_Widget

/// Stands in for a presented approval sheet whose dismissal the test completes by hand: its view sits in a window
/// until `finishDismissal()` runs the completion `dismiss` was given, the way UIKit keeps a dismissing sheet on screen
/// until its transition ends; `tearDown()` takes the view off screen without any completion, the way a host replacing
/// the screen would.
final class DeferredDismissSheetStandIn: UIViewController {
    private let window = UIWindow()
    private var pendingDismissCompletion: (() -> Void)?

    static func onScreen() -> DeferredDismissSheetStandIn {
        let sheet = DeferredDismissSheetStandIn()
        sheet.window.addSubview(sheet.view)
        return sheet
    }

    /// Whether `dismiss` has been called and its completion is still waiting for `finishDismissal()`.
    var isDismissalPending: Bool { pendingDismissCompletion != nil }

    override func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        _ = flag
        pendingDismissCompletion = completion
    }

    /// Ends the dismissal: the view leaves the window and the completion runs, in that order, as UIKit does.
    func finishDismissal() {
        view.removeFromSuperview()
        let completion = pendingDismissCompletion
        pendingDismissCompletion = nil
        completion?()
    }

    /// Takes the sheet off screen without reporting back.
    func tearDown() {
        view.removeFromSuperview()
    }
}

/// ``PayPalCheckoutCoordinator`` completes a checkout from a return or cancel deep link only when the link
/// names the order this checkout started: its `token` must equal the order id from cart prepare. It also reports
/// whether its approval sheet still holds the screen, which is what keeps a second approval from presenting over it.
final class TestPayPalCheckoutCoordinator: XCTestCase {

    private func makeCoordinator(
        cancelURLString: String? = "myapp://paypal/cancel",
        onResult: @escaping (PaymentSheetResult) -> Void = { _ in }
    ) -> PayPalCheckoutCoordinator {
        PayPalCheckoutCoordinator(
            returnURLString: "myapp://paypal/success",
            cancelURLString: cancelURLString,
            expectedOrderId: "ORDER_MOCK",
            completion: onResult
        )
    }

    private func link(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            XCTFail("Test URL should parse: \(string)")
            return URL(fileURLWithPath: "/")
        }
        return url
    }

    /// Completion runs on the main queue; drain it so a wrongful completion has the chance to fail the test.
    private func drainMainQueue() {
        let flush = expectation(description: "main queue flush")
        DispatchQueue.main.async { flush.fulfill() }
        wait(for: [flush], timeout: 1.0)
    }

    // MARK: - Not ours

    func test_handleDeepLinkReturn_unrelatedURL_isNotOurs() {
        let coordinator = makeCoordinator { _ in XCTFail("An unrelated URL must not complete the checkout") }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://other/path?token=ORDER_MOCK")), .notOurs)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("https://example.com/paypal/success?token=ORDER_MOCK")), .notOurs)
        drainMainQueue()
    }

    func test_handleDeepLinkReturn_cancelHostWithoutConfiguredCancelURL_isNotOurs() {
        let coordinator = makeCoordinator(cancelURLString: nil) { _ in XCTFail("No cancel URL is configured") }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/cancel?token=ORDER_MOCK")), .notOurs)
        drainMainQueue()
    }

    // MARK: - Return

    func test_handleDeepLinkReturn_returnWithMatchingToken_completesWithTheOrderId() {
        let completed = expectation(description: "checkout completes")
        let coordinator = makeCoordinator { result in
            XCTAssertEqual(result.outcome, .succeeded)
            XCTAssertEqual(result.transactionId, "ORDER_MOCK")
            completed.fulfill()
        }

        XCTAssertEqual(
            coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=ORDER_MOCK&PayerID=PAYER")),
            .completedReturn
        )
        wait(for: [completed], timeout: 1.0)
    }

    func test_handleDeepLinkReturn_tokenParameterNameIsCaseInsensitive() {
        let completed = expectation(description: "checkout completes")
        let coordinator = makeCoordinator { result in
            XCTAssertEqual(result.outcome, .succeeded)
            completed.fulfill()
        }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?TOKEN=ORDER_MOCK")), .completedReturn)
        wait(for: [completed], timeout: 1.0)
    }

    func test_handleDeepLinkReturn_returnWithoutToken_isRejectedAndStaysPending() {
        let coordinator = makeCoordinator { _ in XCTFail("A link without a token must not complete the checkout") }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success")), .rejectedMissingToken)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=")), .rejectedMissingToken)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?PayerID=PAYER")), .rejectedMissingToken)
        drainMainQueue()
    }

    func test_handleDeepLinkReturn_returnWithAnotherOrdersToken_isRejectedAndStaysPending() {
        let coordinator = makeCoordinator { _ in XCTFail("Another order's token must not complete the checkout") }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=OTHER_ORDER")), .rejectedTokenMismatch)
        // The comparison is exact: order ids are opaque, so case is significant.
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=order_mock")), .rejectedTokenMismatch)
        drainMainQueue()
    }

    func test_handleDeepLinkReturn_rejectedLinkDoesNotConsumeTheCheckout() {
        let completed = expectation(description: "checkout completes from the genuine link")
        let coordinator = makeCoordinator { result in
            XCTAssertEqual(result.transactionId, "ORDER_MOCK")
            completed.fulfill()
        }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=OTHER_ORDER")), .rejectedTokenMismatch)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success")), .rejectedMissingToken)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=ORDER_MOCK")), .completedReturn)
        wait(for: [completed], timeout: 1.0)
    }

    // MARK: - Cancel

    func test_handleDeepLinkReturn_cancelWithMatchingToken_completesCanceled() {
        let completed = expectation(description: "checkout cancels")
        let coordinator = makeCoordinator { result in
            XCTAssertEqual(result.outcome, .canceled)
            completed.fulfill()
        }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/cancel?token=ORDER_MOCK")), .completedCancel)
        wait(for: [completed], timeout: 1.0)
    }

    func test_handleDeepLinkReturn_cancelWithAnotherOrdersToken_isRejectedAndStaysPending() {
        let coordinator = makeCoordinator { _ in XCTFail("Another order's cancel must not end the checkout") }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/cancel?token=OTHER_ORDER")), .rejectedTokenMismatch)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/cancel")), .rejectedMissingToken)
        drainMainQueue()
    }

    // MARK: - Completes once

    func test_handleDeepLinkReturn_afterCompletion_reportsAlreadyDoneWithoutCompletingAgain() {
        let completed = expectation(description: "checkout completes once")
        let coordinator = makeCoordinator { _ in completed.fulfill() }

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=ORDER_MOCK")), .completedReturn)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=ORDER_MOCK")), .alreadyDone)
        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/cancel?token=ORDER_MOCK")), .alreadyDone)
        wait(for: [completed], timeout: 1.0)
        drainMainQueue()
    }

    // MARK: - Whether the approval sheet is on screen

    func test_isApprovalSheetOnScreen_beforeTheSheetIsHandedOver_isTrue() {
        let coordinator = makeCoordinator { _ in XCTFail("Nothing completes this checkout") }

        XCTAssertTrue(coordinator.isApprovalSheetOnScreen, "The sheet is still being put up")
        drainMainQueue()
    }

    func test_isApprovalSheetOnScreen_afterAFailureBeforeAnySheetWasShown_isFalseAtOnce() {
        var result: PaymentSheetResult?
        let coordinator = makeCoordinator { result = $0 }

        coordinator.completeWithFailure("The screen cannot show the sheet")

        XCTAssertFalse(coordinator.isApprovalSheetOnScreen, "A checkout that failed before any sheet was shown holds nothing")
        drainMainQueue()
        XCTAssertEqual(result?.outcome, .failed)
    }

    func test_isApprovalSheetOnScreen_afterTheReturnLinkFinishedTheCheckout_staysTrueUntilTheDismissalCompletes() {
        var result: PaymentSheetResult?
        let coordinator = makeCoordinator { result = $0 }
        let sheet = DeferredDismissSheetStandIn.onScreen()
        coordinator.attachPresentingCheckoutViewController(sheet)
        XCTAssertTrue(coordinator.isApprovalSheetOnScreen)

        XCTAssertEqual(coordinator.handleDeepLinkReturn(link("myapp://paypal/success?token=ORDER_MOCK")), .completedReturn)
        XCTAssertTrue(coordinator.isApprovalSheetOnScreen, "Finished, but the sheet has not begun to dismiss")

        // The dismissal is asked for on the next main-queue turn; the sheet stays in its window while it animates away.
        drainMainQueue()
        XCTAssertTrue(sheet.isDismissalPending)
        XCTAssertTrue(coordinator.isApprovalSheetOnScreen, "Still on screen while the sheet animates away")
        XCTAssertNil(result, "The callback waits for the dismissal to complete")

        sheet.finishDismissal()
        XCTAssertFalse(coordinator.isApprovalSheetOnScreen, "Off screen once the dismissal has completed")
        XCTAssertEqual(result?.outcome, .succeeded)
        XCTAssertEqual(result?.transactionId, "ORDER_MOCK")
    }

    func test_isApprovalSheetOnScreen_afterTheHostTookTheSheetOffScreenWithoutReporting_isFalse() {
        let coordinator = makeCoordinator { _ in XCTFail("Nothing reports back for a sheet the host tore down") }
        let sheet = DeferredDismissSheetStandIn.onScreen()
        coordinator.attachPresentingCheckoutViewController(sheet)
        XCTAssertTrue(coordinator.isApprovalSheetOnScreen)

        sheet.tearDown()

        XCTAssertFalse(coordinator.isApprovalSheetOnScreen, "A sheet out of its window holds nothing, finished or not")
        drainMainQueue()
    }

    func test_isApprovalSheetOnScreen_afterTheBuyerDismissedTheSheet_isFalseOnceItsViewHasLeftTheWindow() {
        var result: PaymentSheetResult?
        let coordinator = makeCoordinator { result = $0 }
        let sheet = DeferredDismissSheetStandIn.onScreen()
        coordinator.attachPresentingCheckoutViewController(sheet)

        // The browser sheet has gone off screen by the time it reports the buyer's dismissal.
        sheet.tearDown()
        coordinator.completeFromUserDismissal(.canceled)

        XCTAssertFalse(coordinator.isApprovalSheetOnScreen)
        drainMainQueue()
        // The coordinator still asks the sheet to dismiss; the callback runs when that call completes.
        XCTAssertTrue(sheet.isDismissalPending)
        sheet.finishDismissal()
        XCTAssertEqual(result?.outcome, .canceled)
    }
}
