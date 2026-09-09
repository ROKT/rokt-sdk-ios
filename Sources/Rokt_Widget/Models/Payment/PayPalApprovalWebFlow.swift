import Foundation
import RoktContracts
import SafariServices
import UIKit

// MARK: - Return URL matching (deep link)

enum PayPalMerchantReturnURL {
    /// Same rules for app deep links: scheme, host, and path must match. The query is not part of the
    /// match; ``PayPalCheckoutCoordinator`` reads the ``token`` PayPal appends and requires it to name
    /// the order this checkout started.
    static func matches(navigated: URL, expectedRedirectString: String) -> Bool {
        guard let expected = URL(string: expectedRedirectString) else { return false }
        guard let es = navigated.scheme?.lowercased(), let et = expected.scheme?.lowercased(), es == et else {
            return false
        }
        let nh = navigated.host?.lowercased() ?? ""
        let eh = expected.host?.lowercased() ?? ""
        guard nh == eh else { return false }
        let np = navigated.path.isEmpty ? "/" : navigated.path
        let ep = expected.path.isEmpty ? "/" : expected.path
        return np == ep
    }
}

// MARK: - Single completion + dismiss (Safari or deep link)

/// Coordinates PayPal checkout completion exactly once. PayPal redirects to ``PaymentContext/returnURL``;
/// iOS opens the host app with that URL, and ``PaymentOrchestrator/handleURLCallback(with:)`` forwards
/// matching URLs here. The hosted approval UI is presented with ``SFSafariViewController``.
final class PayPalCheckoutCoordinator {
    /// What a return/cancel deep link did to this checkout.
    enum DeepLinkOutcome: Equatable {
        /// The URL is not this checkout's return or cancel URL.
        case notOurs
        /// Matched, but the checkout had already completed.
        case alreadyDone
        case completedReturn
        case completedCancel
        /// Matched, but carried no `token`; the checkout stays pending.
        case rejectedMissingToken
        /// Matched, but its `token` is not this checkout's order id; the checkout stays pending.
        case rejectedTokenMismatch
    }

    private let lock = NSLock()
    private var finished = false
    /// Set once the presenter has handed over the approval sheet it put on screen.
    private var sheetAttached = false

    private let returnURLString: String
    private let cancelURLString: String?
    /// PayPal order id from cart prepare; a deep link completes this checkout only when its `token` equals it.
    private let expectedOrderId: String

    private let completion: (PaymentSheetResult) -> Void

    weak var presentingCheckoutViewController: UIViewController?

    /// Whether this checkout's approval sheet still holds the screen, so no other PayPal approval may be presented
    /// over it. Read on the main thread. `false` once the checkout has finished; `true` while the presenter is still
    /// putting the sheet up and has not handed it over yet. After the hand-over the sheet counts as on screen while
    /// its view is in a window: a sheet the host released, or took off screen with the view hierarchy it replaced,
    /// reads as gone even though no cancel or return will ever report it.
    var isApprovalSheetOnScreen: Bool {
        lock.lock()
        let isFinished = finished
        let isAttached = sheetAttached
        lock.unlock()
        if isFinished { return false }
        guard isAttached else { return true }
        return presentingCheckoutViewController?.viewIfLoaded?.window != nil
    }

    init(
        returnURLString: String,
        cancelURLString: String?,
        expectedOrderId: String,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        self.returnURLString = returnURLString
        self.cancelURLString = cancelURLString
        self.expectedOrderId = expectedOrderId
        self.completion = completion
    }

    func attachPresentingCheckoutViewController(_ viewController: UIViewController) {
        presentingCheckoutViewController = viewController
        lock.lock()
        sheetAttached = true
        lock.unlock()
    }

    /// Called when the buyer dismisses ``SFSafariViewController`` without completing approval.
    func completeFromUserDismissal(_ result: PaymentSheetResult) {
        completeOnce(result)
    }

    /// Called when the approval step cannot be presented; ends the checkout with a failure.
    func completeWithFailure(_ message: String) {
        completeOnce(.failed(error: message))
    }

    /// Called from ``PaymentOrchestrator/handleURLCallback(with:)`` when the host app receives the return/cancel deep link.
    ///
    /// The checkout completes only when the link's `token` equals the order id this checkout was started with;
    /// a matching link without that token is reported and otherwise ignored, so the checkout stays pending.
    func handleDeepLinkReturn(_ url: URL) -> DeepLinkOutcome {
        let matchesReturn = PayPalMerchantReturnURL.matches(navigated: url, expectedRedirectString: returnURLString)
        let matchesCancel = cancelURLString.map {
            PayPalMerchantReturnURL.matches(navigated: url, expectedRedirectString: $0)
        } ?? false

        guard matchesReturn || matchesCancel else {
            return .notOurs
        }

        lock.lock()
        let alreadyDone = finished
        lock.unlock()

        if alreadyDone {
            return .alreadyDone
        }

        guard let token = Self.orderToken(in: url) else {
            return .rejectedMissingToken
        }
        guard token == expectedOrderId else {
            return .rejectedTokenMismatch
        }

        if matchesCancel {
            completeOnce(.canceled)
            return .completedCancel
        }
        completeOnce(.succeeded(transactionId: expectedOrderId))
        return .completedReturn
    }

    private static func orderToken(in url: URL) -> String? {
        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name.caseInsensitiveCompare("token") == .orderedSame }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    private func completeOnce(_ result: PaymentSheetResult) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        lock.unlock()

        let checkoutViewController = presentingCheckoutViewController
        if let safari = checkoutViewController as? SFSafariViewController {
            safari.payPalApprovalRetainedDelegate = nil
        }
        let callback = completion

        DispatchQueue.main.async {
            if let checkoutViewController {
                checkoutViewController.dismiss(animated: true) {
                    callback(result)
                }
            } else {
                callback(result)
            }
        }
    }
}

// MARK: - Presenter protocol

/// Presents PayPal's order approval experience.
///
/// PayPal's create-order response includes HATEOAS links; the ``rel`` value `approve` points at the
/// hosted page where the buyer approves the order (see PayPal Orders API — response `links`).
/// Loading that URL in ``SFSafariViewController`` and completing when iOS delivers the redirect to
/// ``PaymentContext/returnURL`` (custom URL scheme or universal link) finishes the browser-based approval step.
/// PayPal also offers a dedicated iOS SDK for apps that prefer a non-web integration.
///
/// - SeeAlso: [Orders API — Create order](https://developer.paypal.com/docs/api/orders/v2/#orders_create)
protocol PayPalApprovalPresenting: AnyObject {
    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    )
}

/// Default presenter that loads the approval URL in ``SFSafariViewController``.
final class PayPalApprovalWebPresenter: PayPalApprovalPresenting {
    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    ) {
        // `SFSafariViewController` only accepts http/https URLs; anything else ends the checkout instead.
        guard approvalURL.isWebURLWithHost() else {
            RoktLogger.shared.warning(
                "\(PaymentOrchestrator.devicePayErrorCode) \(PaymentOrchestrator.payPalApprovalURLInvalidMessage)"
            )
            checkoutCoordinator.completeWithFailure(PaymentOrchestrator.payPalApprovalURLInvalidMessage)
            return
        }
        DispatchQueue.main.async {
            // UIKit refuses to present over a view controller that is already presenting, and reports the refusal
            // to no one: the present completion is skipped and no delegate call follows. Fail the checkout here
            // instead, so its result still reaches the caller and the checkout is not left waiting for ever.
            guard viewController.presentedViewController == nil else {
                RoktLogger.shared.warning(
                    "\(PaymentOrchestrator.devicePayErrorCode) \(PaymentOrchestrator.payPalApprovalPresenterBusyMessage)"
                )
                checkoutCoordinator.completeWithFailure(PaymentOrchestrator.payPalApprovalPresenterBusyMessage)
                return
            }
            let safari = SFSafariViewController(url: approvalURL)
            safari.modalPresentationStyle = .fullScreen
            let delegate = PayPalApprovalSafariDelegate(checkoutCoordinator: checkoutCoordinator)
            safari.payPalApprovalRetainedDelegate = delegate
            safari.delegate = delegate
            viewController.present(safari, animated: true) {
                checkoutCoordinator.attachPresentingCheckoutViewController(safari)
            }
        }
    }
}

// MARK: - Safari delegate

private enum PayPalApprovalAssociatedKeys {
    static var retainedDelegate = 0
}

private extension SFSafariViewController {
    var payPalApprovalRetainedDelegate: PayPalApprovalSafariDelegate? {
        get {
            objc_getAssociatedObject(self, &PayPalApprovalAssociatedKeys.retainedDelegate) as? PayPalApprovalSafariDelegate
        }
        set {
            objc_setAssociatedObject(
                self,
                &PayPalApprovalAssociatedKeys.retainedDelegate,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private final class PayPalApprovalSafariDelegate: NSObject, SFSafariViewControllerDelegate {
    private weak var checkoutCoordinator: PayPalCheckoutCoordinator?

    init(checkoutCoordinator: PayPalCheckoutCoordinator) {
        self.checkoutCoordinator = checkoutCoordinator
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        checkoutCoordinator?.completeFromUserDismissal(.canceled)
    }
}
