import Foundation
import ObjectiveC
import SafariServices
internal import RoktUXHelper

class LinkHandler: NSObject {
    typealias ExternalURLOpener = (URL, [UIApplication.OpenExternalURLOptionsKey: Any], @escaping (Bool) -> Void) -> Void
    private static let urlDiagnosticCode = "[URL]"
    private static let urlOpenDiagnosticCode = "[URL_OPEN]"
    private final class CompletionHandlerBox: NSObject {
        let handler: () -> Void

        init(_ handler: @escaping () -> Void) {
            self.handler = handler
        }
    }
    private static var completionHandlerAssociationKey: UInt8 = 0
    private enum FailureReason: String {
        case invalidURL = "Invalid URL"
        case unsupportedInternalURL = "Unsupported internal URL scheme"
        case externalOpenFailed = "External URL could not be opened"
        case missingPresenter = "No view controller available for internal URL"
    }

    private let openExternalURL: ExternalURLOpener
    private let reportFailure: (String, String) -> Void
    private let presentingViewController: () -> UIViewController?

    init(openExternalURL: @escaping ExternalURLOpener = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        },
         reportFailure: @escaping (String, String) -> Void = { code, reason in
            RoktAPIHelper.sendDiagnostics(message: code, callStack: reason)
        },
         presentingViewController: @escaping () -> UIViewController? = { UIApplication.topViewController() }) {
        self.openExternalURL = openExternalURL
        self.reportFailure = reportFailure
        self.presentingViewController = presentingViewController
        super.init()
    }

    private func openURL(url: URL, type: RoktUXOpenURLType,
                         completion: (() -> Void)?, failure: (() -> Void)?) {
        switch type {
        case .internally:
            guard url.isWebURL() else {
                reportFailure(Self.urlDiagnosticCode, FailureReason.unsupportedInternalURL.rawValue)
                failure?()
                return
            }
            guard let presenter = presentingViewController() else {
                reportFailure(Self.urlOpenDiagnosticCode, FailureReason.missingPresenter.rawValue)
                failure?()
                return
            }
            let safariVC = SFSafariViewController(url: url)
            if let completion {
                objc_setAssociatedObject(safariVC, &Self.completionHandlerAssociationKey,
                                         CompletionHandlerBox(completion), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            safariVC.modalPresentationStyle = .overFullScreen
            safariVC.delegate = self
            presenter.present(safariVC, animated: true)
        case .externally,
                .passthrough:
            completion?()
            openExternalLink(url, failure: failure)
        }
    }

    private func openExternalLink(_ url: URL, failure: (() -> Void)?) {
        var finished = false
        var requestedFallback = false
        let complete: (Bool) -> Void = { [reportFailure] opened in
            guard !finished else { return }
            finished = true
            guard !opened else { return }
            reportFailure(Self.urlOpenDiagnosticCode, FailureReason.externalOpenFailed.rawValue)
            failure?()
        }
        openExternalURL(url, [.universalLinksOnly: true]) { [openExternalURL] opened in
            guard !finished else { return }
            if opened {
                complete(true)
            } else if !requestedFallback {
                requestedFallback = true
                openExternalURL(url, [.init(rawValue: "isRokt"): true], complete)
            }
        }
    }

    func linkHandler(urlString: String,
                     type: RoktUXOpenURLType,
                     completionHandler: (() -> Void)?,
                     failureHandler: (() -> Void)? = nil) {
        // Preserve the established callback contract for each path. External links complete
        // eagerly before opening, so an asynchronous open failure arrives afterwards. Invalid
        // input is diagnosed synchronously before its legacy completion. Internal failures do
        // not complete because completion represents dismissing the in-app browser.
        guard let url = URL(string: urlString) else {
            reportFailure(Self.urlDiagnosticCode, FailureReason.invalidURL.rawValue)
            failureHandler?()
            completionHandler?()
            return
        }
        openURL(url: url, type: type, completion: completionHandler, failure: failureHandler)
    }

}

extension LinkHandler: SFSafariViewControllerDelegate {
    // For internally-opened links the completion (offer progression / close) must run only
    // once the in-app browser is actually dismissed. Firing it while Safari is still
    // presented would, on the last/only offer, close the placement and tear down the
    // Safari controller that the placement presents.
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        let handler = (objc_getAssociatedObject(controller, &Self.completionHandlerAssociationKey)
            as? CompletionHandlerBox)?.handler
        objc_setAssociatedObject(controller, &Self.completionHandlerAssociationKey, nil,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        handler?()
    }
}
