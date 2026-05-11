import UIKit
import Rokt_Widget

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print(url)
        return Rokt.handleURLCallback(with: url)
    }
}
