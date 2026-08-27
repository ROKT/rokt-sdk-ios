import Foundation
import SafariServices
internal import RoktUXHelper

class LinkHandler: NSObject {
    typealias ExternalURLOpener = (URL, [UIApplication.OpenExternalURLOptionsKey: Any], @escaping (Bool) -> Void) -> Void
    private static let urlDiagnosticCode = "[URL]"

    private var completionHandler: (() -> Void)?
    private let openExternalURL: ExternalURLOpener
    private let reportFailure: (String) -> Void

    override init() {
        openExternalURL = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        }
        reportFailure = { url in
            RoktAPIHelper.sendDiagnostics(message: LinkHandler.urlDiagnosticCode, callStack: url)
        }
        super.init()
    }

    init(openExternalURL: @escaping ExternalURLOpener, reportFailure: @escaping (String) -> Void) {
        self.openExternalURL = openExternalURL
        self.reportFailure = reportFailure
        super.init()
    }

    private func openURL(url: URL, type: RoktUXOpenURLType,
                         completion: (() -> Void)?, failure: (() -> Void)?) {
        switch type {
        case .internally:
            guard url.isWebURL() else {
                reportFailure(url.absoluteString)
                failure?()
                return
            }
            completionHandler = completion
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .overFullScreen
            safariVC.delegate = self
            UIApplication.topViewController()?.present(safariVC, animated: true)
        case .externally,
                .passthrough:
            openExternalLink(url, completion: completion, failure: failure)
        }
    }

    private func openExternalLink(_ url: URL, completion: (() -> Void)?, failure: (() -> Void)?) {
        var finished = false
        var requestedFallback = false
        let complete: (Bool) -> Void = { [reportFailure] opened in
            guard !finished else { return }
            finished = true
            if opened {
                completion?()
            } else {
                reportFailure(url.absoluteString)
                failure?()
            }
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

    func linkHandler(url: URL,
                     type: RoktUXOpenURLType,
                     completionHandler: (() -> Void)?,
                     failureHandler: (() -> Void)? = nil) {
        openURL(url: url, type: type, completion: completionHandler, failure: failureHandler)
    }

    func linkHandler(urlString: String,
                     type: RoktUXOpenURLType,
                     completionHandler: (() -> Void)?,
                     failureHandler: (() -> Void)? = nil) {
        guard let url = URL(string: urlString) else {
            reportFailure(urlString)
            failureHandler?()
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
        let handler = completionHandler
        completionHandler = nil
        handler?()
    }
}
