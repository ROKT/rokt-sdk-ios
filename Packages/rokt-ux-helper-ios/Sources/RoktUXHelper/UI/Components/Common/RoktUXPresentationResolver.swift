import UIKit

@available(iOS 15.0, *)
enum RoktUXPresentationResolver {
    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    static func stableTopViewController(
        startingAt controller: UIViewController?,
        isPresenterUsable: (UIViewController) -> Bool = defaultIsPresenterUsable
    ) -> UIViewController? {
        guard let controller, isPresenterUsable(controller) else {
            return nil
        }

        var topController = controller
        while let presentedViewController = topController.presentedViewController {
            guard isPresenterUsable(presentedViewController) else {
                break
            }
            topController = presentedViewController
        }

        return topController
    }

    private static func defaultIsPresenterUsable(_ controller: UIViewController) -> Bool {
        controller.viewIfLoaded?.window != nil &&
        !controller.isBeingDismissed &&
        !controller.isMovingFromParent
    }
}
