import Foundation
import UIKit

extension UIResponder {
    /// Extension to retrieve the parent view controller.
    public var parentViewControllers: UIViewController? {
        return next as? UIViewController ?? next?.parentViewControllers
    }
}
