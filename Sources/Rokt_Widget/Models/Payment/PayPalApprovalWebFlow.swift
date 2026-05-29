import Foundation
import RoktContracts
import SafariServices
import UIKit

// MARK: - Return URL matching (deep link)

enum PayPalMerchantReturnURL {
    /// Same rules for app deep links: scheme, host, and path must match
    /// (PayPal appends query parameters such as ``token``).
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
    private let lock = NSLock()
    private var finished = false

    private let returnURLString: String
    private let cancelURLString: String?

    private let completion: (PaymentSheetResult) -> Void

    weak var presentingCheckoutViewController: UIViewController?

    init(returnURLString: String, cancelURLString: String?, completion: @escaping (PaymentSheetResult) -> Void) {
        self.returnURLString = returnURLString
        self.cancelURLString = cancelURLString
        self.completion = completion
    }

    func attachPresentingCheckoutViewController(_ viewController: UIViewController) {
        presentingCheckoutViewController = viewController
    }

    /// Called when the buyer dismisses ``SFSafariViewController`` without completing approval.
    func completeFromUserDismissal(_ result: PaymentSheetResult) {
        completeOnce(result)
    }

    /// Called from ``PaymentOrchestrator/handleURLCallback(with:)`` when the host app receives the return/cancel deep link.
    /// - Returns: `true` if the URL matches the configured return or cancel URL (including after checkout already finished).
    @discardableResult
    func handleDeepLinkReturn(_ url: URL) -> Bool {
        let matchesReturn = PayPalMerchantReturnURL.matches(navigated: url, expectedRedirectString: returnURLString)
        let matchesCancel = cancelURLString.map {
            PayPalMerchantReturnURL.matches(navigated: url, expectedRedirectString: $0)
        } ?? false

        guard matchesReturn || matchesCancel else {
            return false
        }

        lock.lock()
        let alreadyDone = finished
        lock.unlock()

        if alreadyDone {
            return true
        }

        if matchesCancel {
            completeOnce(.canceled)
        } else {
            let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name.caseInsensitiveCompare("token") == .orderedSame }?
                .value
            completeOnce(.succeeded(transactionId: token ?? url.absoluteString))
        }
        return true
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
        DispatchQueue.main.async {
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
