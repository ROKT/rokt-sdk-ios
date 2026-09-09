import UIKit
import XCTest
@testable import Rokt_Widget

/// Stands in for a screen that is already showing another view. UIKit reports that view through
/// `presentedViewController` for a controller that is presenting, or whose ancestor is, and refuses a further present.
final class AlreadyPresentingViewController: UIViewController {
    private let viewAlreadyOnTop = UIViewController()

    override var presentedViewController: UIViewController? { viewAlreadyOnTop }
}

/// ``PayPalApprovalWebPresenter`` loads the approval URL in `SFSafariViewController`, which accepts only
/// http/https URLs. Any other URL must end the checkout with a failure instead of being presented, and so must a
/// screen that is already presenting another view, since UIKit would refuse the sheet without reporting back.
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

    func test_presentPayPalApproval_whenTheScreenAlreadyPresentsAnotherView_failsCheckoutWithoutPresenting() throws {
        let approvalURL = try XCTUnwrap(URL(string: "https://www.paypal.com/checkoutnow?token=MOCK"))
        let failed = expectation(description: "checkout fails when the screen is already presenting another view")
        let coordinator = makeCoordinator { result in
            XCTAssertEqual(result.outcome, .failed)
            XCTAssertEqual(result.errorMessage, PaymentOrchestrator.payPalApprovalPresenterBusyMessage)
            failed.fulfill()
        }

        PayPalApprovalWebPresenter().presentPayPalApproval(
            approvalURL: approvalURL,
            from: AlreadyPresentingViewController(),
            checkoutCoordinator: coordinator
        )

        wait(for: [failed], timeout: 1.0)
    }
}
