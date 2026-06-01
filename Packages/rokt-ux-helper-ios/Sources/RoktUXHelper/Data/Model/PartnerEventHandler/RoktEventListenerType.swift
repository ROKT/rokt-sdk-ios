import Foundation

enum RoktEventListenerType: String, CaseIterable {
    case OfferEngagement
    case PositiveEngagement
    case ShowLoadingIndicator
    case HideLoadingIndicator
    case PlacementInteractive
    case PlacementReady
    case PlacementClosed
    case PlacementCompleted
    case PlacementFailure
    case FirstPositiveEngagement
    case OpenUrl
    case CartItemInstantPurchase
    case CartItemDevicePay
    case CartItemForwardPayment
}
