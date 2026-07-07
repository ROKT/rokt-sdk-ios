import Foundation
import SafariServices
internal import RoktUXHelper

class LinkHandler: NSObject {
    private static let urlDiagnosticCode = "[URL]"

    private var completionHandler: (() -> Void)?

    override init() {
        super.init()
    }

    private func openURL(url: URL, type: RoktUXOpenURLType) {
        func openExternalLink(_ url: URL) {
            // Try to open the URL with universal links first
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
                if !opened {
                    // If universal links fail, open the URL in external browser
                    UIApplication.shared.open(url, options: [.init(rawValue: "isRokt"): true])
                }
            }
        }

        switch type {
        case .internally:
            guard url.isWebURL() else {
                RoktAPIHelper.sendDiagnostics(message: Self.urlDiagnosticCode,
                                              callStack: url.absoluteString)
                return
            }
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .overFullScreen
            safariVC.delegate = self
            UIApplication.topViewController()?.present(safariVC, animated: true)
        case .externally,
                .passthrough:
            completionHandler?()
            openExternalLink(url)
        }
    }

    func linkHandler(url: URL,
                     type: RoktUXOpenURLType,
                     completionHandler: (() -> Void)?) {
        self.completionHandler = completionHandler
        openURL(url: url, type: type)
    }

    func linkHandler(urlString: String,
                     type: RoktUXOpenURLType,
                     completionHandler: (() -> Void)?) {
        self.completionHandler = completionHandler
        guard let url = URL(string: urlString) else {
            RoktAPIHelper.sendDiagnostics(message: Self.urlDiagnosticCode, callStack: urlString)

            completionHandler?()
            return
        }
        openURL(url: url, type: type)
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
