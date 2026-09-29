import UIKit
import Rokt_Widget

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let automation = AutomationLaunchConfig.current
        if automation.isAutoRunEnabled {
            // Recorded before anything else so a run that dies during init still says how it
            // was configured. Never log the tag id itself.
            AutomationTranscript.shared.record("AutomationLaunch", [
                "hasTagId": automation.tagId != nil,
                "environment": automation.environment?.rawValue ?? "buildConfiguration",
                "pageIdentifier": automation.pageIdentifier ?? "",
                "location": automation.location ?? "",
                "attributeCount": automation.attributes.count
            ])
        }
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print(url)
        return Rokt.handleURLCallback(with: url)
    }
}
