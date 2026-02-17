import Foundation
import SafariServices
internal import RoktUXHelper

class LinkHandler {

    private var completionHandler: (() -> Void)?

    init() {}

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
                RoktAPIHelper.sendDiagnostics(message: kUrlErrorCode,
                                              callStack: url.absoluteString)
                return
            }
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .overFullScreen
            UIApplication.topViewController()?.present(safariVC, animated: true, completion: { [weak self] in
                self?.completionHandler?()
            })
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
            RoktAPIHelper.sendDiagnostics(message: kUrlErrorCode, callStack: urlString)

            completionHandler?()
            return
        }
        openURL(url: url, type: type)
    }

}
