import UIKit
import Rokt_Widget

class AppDelegate: UIResponder, UIApplicationDelegate, UIWindowSceneDelegate {

    var window: UIWindow?

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
