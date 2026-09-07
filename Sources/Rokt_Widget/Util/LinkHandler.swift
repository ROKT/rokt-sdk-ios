import Foundation
import SafariServices
internal import RoktUXHelper

class LinkHandler: NSObject {
    typealias ExternalURLOpener = (URL, [UIApplication.OpenExternalURLOptionsKey: Any], @escaping (Bool) -> Void) -> Void
    private static let urlDiagnosticCode = "[URL]"
    private enum FailureReason: String {
        case invalidURL = "Invalid URL"
        case unsupportedInternalURL = "Unsupported internal URL scheme"
        case externalOpenFailed = "External URL could not be opened"
        case missingPresenter = "No view controller available for internal URL"
    }

    private var completionHandlers: [ObjectIdentifier: () -> Void] = [:]
    private let openExternalURL: ExternalURLOpener
    private let reportFailure: (String) -> Void
    private let presentingViewController: () -> UIViewController?

    init(
        openExternalURL: @escaping ExternalURLOpener = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        },
        reportFailure: @escaping (String) -> Void = { reason in
            RoktAPIHelper.sendDiagnostics(message: LinkHandler.urlDiagnosticCode, callStack: reason)
        },
        presentingViewController: @escaping () -> UIViewController? = { UIApplication.topViewController() }
    ) {
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
                reportFailure(FailureReason.unsupportedInternalURL.rawValue)
                failure?()
                return
            }
            guard let presenter = presentingViewController() else {
                reportFailure(FailureReason.missingPresenter.rawValue)
                failure?()
                return
            }
            let safariVC = SFSafariViewController(url: url)
            if let completion {
                completionHandlers[ObjectIdentifier(safariVC)] = completion
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
            reportFailure(FailureReason.externalOpenFailed.rawValue)
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
        guard let url = URL(string: urlString) else {
            reportFailure(FailureReason.invalidURL.rawValue)
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
        let handler = completionHandlers.removeValue(forKey: ObjectIdentifier(controller))
        handler?()
    }
}
