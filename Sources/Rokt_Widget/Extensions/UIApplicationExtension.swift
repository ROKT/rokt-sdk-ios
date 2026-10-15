import UIKit

internal extension UIApplication {
    class func topViewController(controller: UIViewController? = sceneKeyWindow()?.rootViewController)
    -> UIViewController? {

        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }

    /// The key window of a foreground-active window scene, or of any connected window scene when
    /// none is foreground-active. Nil when no connected window scene has a key window.
    class func sceneKeyWindow() -> UIWindow? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foregroundActive = windowScenes.filter { $0.activationState == .foregroundActive }
        return (foregroundActive + windowScenes).flatMap(\.windows).first(where: \.isKeyWindow)
    }
}
