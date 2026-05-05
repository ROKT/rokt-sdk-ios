import Foundation
import RoktContracts
import UIKit
import WebKit

// MARK: - Return URL matching (embedded web view + deep link)

enum PayPalMerchantReturnURL {
    /// Same rules for ``WKWebView`` navigation and app deep links: scheme, host, and path must match
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

// MARK: - Single completion + dismiss (WKWebView path or deep link)

/// Coordinates PayPal checkout completion exactly once. PayPal typically redirects to a **deep link**
/// ``PaymentContext/returnURL``; iOS may open your app with that URL instead of delivering navigation
/// inside ``WKWebView``, so ``PaymentOrchestrator/handleURLCallback(with:)`` forwards matching URLs here.
final class PayPalCheckoutCoordinator {
    private let lock = NSLock()
    private var finished = false

    private let returnURLString: String
    private let cancelURLString: String?

    private let completion: (PaymentSheetResult) -> Void

    weak var presentingNavigationController: UINavigationController?

    init(returnURLString: String, cancelURLString: String?, completion: @escaping (PaymentSheetResult) -> Void) {
        self.returnURLString = returnURLString
        self.cancelURLString = cancelURLString
        self.completion = completion
    }

    func attachPresentingNavigationController(_ navigationController: UINavigationController) {
        presentingNavigationController = navigationController
    }

    /// Called when the embedded web view intercepts a matching redirect (in-app navigation).
    func completeFromEmbeddedCheckout(_ result: PaymentSheetResult) {
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

        let nav = presentingNavigationController
        let callback = completion

        DispatchQueue.main.async {
            if let nav {
                nav.dismiss(animated: true) {
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
/// Loading that URL in a web view and intercepting the subsequent redirect to the merchant
/// ``PaymentContext/returnURL`` completes the browser-based approval step. Return URLs are often
/// **deep links**; when iOS opens the host app with that URL, ``PayPalCheckoutCoordinator/handleDeepLinkReturn``
/// completes the flow. PayPal also offers a dedicated iOS SDK for apps that prefer a non-web integration.
///
/// - SeeAlso: [Orders API — Create order](https://developer.paypal.com/docs/api/orders/v2/#orders_create)
protocol PayPalApprovalPresenting: AnyObject {
    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    )
}

/// Default presenter that loads the approval URL in a ``WKWebView`` and listens for redirects to
/// the partner return or cancel URLs supplied in ``PaymentContext``.
final class PayPalApprovalWebPresenter: PayPalApprovalPresenting {
    func presentPayPalApproval(
        approvalURL: URL,
        from viewController: UIViewController,
        checkoutCoordinator: PayPalCheckoutCoordinator
    ) {
        DispatchQueue.main.async {
            let screen = PayPalApprovalWebViewController(
                approvalURL: approvalURL,
                checkoutCoordinator: checkoutCoordinator
            )
            let nav = UINavigationController(rootViewController: screen)
            nav.modalPresentationStyle = .fullScreen
            viewController.present(nav, animated: true) {
                checkoutCoordinator.attachPresentingNavigationController(nav)
            }
        }
    }
}

// MARK: - Web view controller

private final class PayPalApprovalWebViewController: UIViewController, WKNavigationDelegate {
    private let approvalURL: URL
    private let checkoutCoordinator: PayPalCheckoutCoordinator

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(approvalURL: URL, checkoutCoordinator: PayPalCheckoutCoordinator) {
        self.approvalURL = approvalURL
        self.checkoutCoordinator = checkoutCoordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "PayPal"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in
                self?.checkoutCoordinator.completeFromEmbeddedCheckout(.canceled)
            }
        )

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        webView.load(URLRequest(url: approvalURL))
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if checkoutCoordinator.handleDeepLinkReturn(url) {
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}
