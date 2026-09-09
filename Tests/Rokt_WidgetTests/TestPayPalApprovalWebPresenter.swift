import UIKit
import XCTest
@testable import Rokt_Widget

/// ``PayPalApprovalWebPresenter`` loads the approval URL in `SFSafariViewController`, which accepts only
/// http/https URLs. Any other URL must end the checkout with a failure instead of being presented.
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
}
