import UIKit
import Rokt_Widget

class AppDelegate: UIResponder, UIApplicationDelegate, UIWindowSceneDelegate {

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

    // With a scene manifest, URLs reach the scene delegate instead of `application(_:open:options:)`.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        handle(connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handle(URLContexts)
    }

    private func handle(_ urlContexts: Set<UIOpenURLContext>) {
        for context in urlContexts {
            _ = Rokt.handleURLCallback(with: context.url)
        }
    }
}
