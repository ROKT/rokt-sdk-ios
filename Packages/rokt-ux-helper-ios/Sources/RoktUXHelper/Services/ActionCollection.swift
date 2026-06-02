import Foundation

/// Represents the various types of user or system actions that can occur within the Rokt experience.
enum RoktActionType: String {
    case close
    case nextOffer
    case unload
    case positiveEngaged

    /// Informs listening distributions to navigate to next. Next will be different depending on the distrution e.g.
    /// ``OneByOneDistributionComponent`` - would go to next offer
    /// ``GroupedDistributionComponent`` - would go to the next page or group
    ///
    /// Triggered by ``ProgressControlComponent``
    case progressControlNext

    /// Informs listening distributions to navigate to previous. Previous will be different depending on the distrution e.g.
    /// ``OneByOneDistributionComponent`` - would go to previous offer
    /// ``GroupedDistributionComponent`` - would go to the previous page or group
    ///
    /// Triggered by ``ProgressControlComponent``
    case progressControlPrevious

    case checkBoundingBox
    case checkBoundingBoxMissized
    case toggleCustomState
}

protocol ActionCollecting {
    typealias ShareFunction = ((Any?) -> Void)

    subscript(actionType: RoktActionType) -> ShareFunction { get set }

    func reset()
}

class ActionCollection: ActionCollecting {
    private let internalQueue = DispatchQueue(label: "com.rokt.actions",
                                              qos: .default,
                                              attributes: .concurrent)

    private var callbackMap: [RoktActionType: ShareFunction] = [RoktActionType: ShareFunction]()

    subscript(actionType: RoktActionType) -> ShareFunction {
        get {
            internalQueue.sync {
                if let callback = callbackMap[actionType] {
                    return { (param: Any?) in return callback(param) }
                }
                return { (_: Any?) in return }
            }
        }

        set {
            internalQueue.sync {
                callbackMap[actionType] = newValue
            }
        }
    }

    func reset() {
        internalQueue.sync {
            callbackMap.removeAll()
        }
    }
}
