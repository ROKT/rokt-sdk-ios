import Foundation

protocol Bag: AnyObject {
    var uxHelper: AnyObject? { get }
    var loadedPlacements: Int { get set }
    var instantPurchaseInitiated: Bool { get set }
    var onRoktEvent: ((RoktEvent) -> Void)? { get }
}

class ExecuteStateBag: Bag {
    var uxHelper: AnyObject?
    var loadedPlacements: Int = 0
    var instantPurchaseInitiated: Bool = false
    var onRoktEvent: ((RoktEvent) -> Void)?

    init(
        uxHelper: AnyObject? = nil,
        onRoktEvent: ((RoktEvent) -> Void)?
    ) {
        self.uxHelper = uxHelper
        self.onRoktEvent = onRoktEvent
    }
}
