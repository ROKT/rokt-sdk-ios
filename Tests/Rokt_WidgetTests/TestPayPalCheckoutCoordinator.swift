import XCTest
@testable import Rokt_Widget

/// ``PayPalCheckoutCoordinator`` completes a checkout from a return or cancel deep link only when the link
/// names the order this checkout started: its `token` must equal the order id from cart prepare.
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
}
