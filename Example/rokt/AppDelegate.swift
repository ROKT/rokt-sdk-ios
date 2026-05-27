import UIKit
import Rokt_Widget

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        applyHTTPRouteOverrideFromInfoPlistIfPresent()
        return true
    }

    /// Optional `RoktHTTPRouteOverride` in Info.plist — same sanitized branch as transactions SBS / `rokt-route-override`.
    private func applyHTTPRouteOverrideFromInfoPlistIfPresent() {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "RoktHTTPRouteOverride") as? String else {
            return
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        Rokt.setHTTPRouteOverride(trimmed.isEmpty ? nil : trimmed)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print(url)
        return Rokt.handleURLCallback(with: url)
    }
}
