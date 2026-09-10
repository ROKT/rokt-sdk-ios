import UIKit
import XCTest
@testable import Rokt_Widget

/// Stands in for a screen that is already showing another view. UIKit reports that view through
/// `presentedViewController` for a controller that is presenting, or whose ancestor is, and refuses a further present.
final class AlreadyPresentingViewController: UIViewController {
    private let viewAlreadyOnTop = UIViewController()

    override var presentedViewController: UIViewController? { viewAlreadyOnTop }
}

/// Stands in for a screen on its way off: its view is still in a window, but UIKit reports the controller as being
/// dismissed, and drops a further present from it without reporting back.
final class DismissingViewController: UIViewController {
    private let window = UIWindow()

    static func onScreen() -> DismissingViewController {
        let viewController = DismissingViewController()
        viewController.window.addSubview(viewController.view)
        return viewController
    }

    override var isBeingDismissed: Bool { true }
}

/// ``PayPalApprovalWebPresenter`` loads the approval URL in `SFSafariViewController`, which accepts only
/// http/https URLs. Any other URL must end the checkout with a failure instead of being presented, and so must a
/// cleartext (http) URL whose host is not a loopback address, and a screen that cannot show the sheet: one already
/// presenting another view, one whose view is in no window, or one being dismissed. UIKit drops the present in each
/// of those states without calling the completion or the delegate.
final class TestPayPalApprovalWebPresenter: XCTestCase {

    private func makeCoordinator(onResult: @escaping (PaymentSheetResult) -> Void) -> PayPalCheckoutCoordinator {
        PayPalCheckoutCoordinator(
            returnURLString: "myapp://paypal/success",
            cancelURLString: nil,
            expectedOrderId: "ORDER_MOCK",
            completion: onResult
        )
    }

    private func assertPresenterRejects(_ urlString: String) {
        guard let approvalURL = URL(string: urlString) else {
            XCTFail("Test URL should parse: \(urlString)")
            return
        }
        let failed = expectation(description: "checkout fails for \(urlString)")
        let coordinator = makeCoordinator { result in
            XCTAssertEqual(result.outcome, .failed, urlString)
            XCTAssertEqual(result.errorMessage, PaymentOrchestrator.payPalApprovalURLInvalidMessage, urlString)
            failed.fulfill()
        }

        PayPalApprovalWebPresenter().presentPayPalApproval(
            approvalURL: approvalURL,
            from: UIViewController(),
            checkoutCoordinator: coordinator
        )

        wait(for: [failed], timeout: 1.0)
    }

    func test_presentPayPalApproval_nonWebApprovalURL_failsCheckoutWithoutPresenting() {
        for urlString in ["myapp://x", "javascript:1", "file:///etc", "paypal.com/checkoutnow"] {
            assertPresenterRejects(urlString)
        }
    }

    func test_presentPayPalApproval_webSchemeWithoutHost_failsCheckoutWithoutPresenting() {
        assertPresenterRejects("https:///x")
    }

    func test_presentPayPalApproval_cleartextNonLoopbackApprovalURL_failsCheckoutWithoutPresenting() {
        assertPresenterRejects("http://www.example.com/checkoutnow")
    }

    /// The URL is fine; the screen is not. The checkout must end with `message` through the ordinary completion, which
    /// a present UIKit dropped would never reach.
    private func assertPresenterFailsCheckout(
        approvalURLString: String = "https://www.paypal.com/checkoutnow?token=MOCK",
        from viewController: UIViewController,
        expecting message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let approvalURL = try XCTUnwrap(URL(string: approvalURLString), file: file, line: line)
        let failed = expectation(description: "checkout fails for a screen that cannot show the sheet")
        let coordinator = makeCoordinator { result in
            XCTAssertEqual(result.outcome, .failed, file: file, line: line)
            XCTAssertEqual(result.errorMessage, message, file: file, line: line)
            failed.fulfill()
        }

        PayPalApprovalWebPresenter().presentPayPalApproval(
            approvalURL: approvalURL,
            from: viewController,
            checkoutCoordinator: coordinator
        )

        wait(for: [failed], timeout: 1.0)
    }

    func test_presentPayPalApproval_whenTheScreenAlreadyPresentsAnotherView_failsCheckoutWithoutPresenting() throws {
        try assertPresenterFailsCheckout(
            from: AlreadyPresentingViewController(),
            expecting: PaymentOrchestrator.payPalApprovalPresenterBusyMessage
        )
    }

    func test_presentPayPalApproval_whenTheScreenIsNotInAWindow_failsCheckoutWithoutPresenting() throws {
        // A plain view controller never shown: its view is in no window.
        try assertPresenterFailsCheckout(
            from: UIViewController(),
            expecting: PaymentOrchestrator.payPalApprovalPresenterOffScreenMessage
        )
    }

    /// A cleartext URL on a loopback host gets past the URL check: the checkout then fails only on the screen, which is
    /// in no window, so the failure names the screen and not the URL, and nothing is presented.
    func test_presentPayPalApproval_cleartextLoopbackApprovalURL_passesURLGuard() throws {
        try assertPresenterFailsCheckout(
            approvalURLString: "http://localhost:9011/approve",
            from: UIViewController(),
            expecting: PaymentOrchestrator.payPalApprovalPresenterOffScreenMessage
        )
    }

    func test_presentPayPalApproval_whenTheScreenIsBeingDismissed_failsCheckoutWithoutPresenting() throws {
        try assertPresenterFailsCheckout(
            from: DismissingViewController.onScreen(),
            expecting: PaymentOrchestrator.payPalApprovalPresenterOffScreenMessage
        )
    }
}
