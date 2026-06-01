import Foundation

/// Enum representing different types of platform events
/// Platform events are an essential part of integration and it has to be sent to Rokt via your backend
public enum RoktUXEventType: String, Codable, CaseIterable {
    /// Triggered when the first offer is displayed and again when the user navigates to a different offer.
    case SignalImpression
    /// Indicates the initialisation of the ROKT
    case SignalInitialize
    /// Triggered when the layout started loading.
    case SignalLoadStart
    /// Triggered when the layout finished loading.
    case SignalLoadComplete
    /// Triggered when the user engages with the offer.
    case SignalGatedResponse
    /// Triggered when the user engages with the offer.
    case SignalResponse
    /// Triggered when the layout is dismissed by the user.
    case SignalDismissal
    /// Triggered when there is an error on RoktUXHelper.
    case SignalSdkDiagnostic
    /// Triggered when user engages with the offer area.
    case SignalActivation
    /// Triggered when the content displays to user.
    case SignalViewed
    /// Triggered when the user clicks catalog response button.
    case SignalCartItemInstantPurchaseInitiated
    /// Triggered when instant purchase succeeds
    case SignalCartItemInstantPurchase
    /// Triggered when instant purchase fails
    case SignalCartItemInstantPurchaseFailure
    /// Triggered when an instant purchase offer is explicitly dismissed.
    case SignalInstantPurchaseDismissal
    /// Triggered when the user interacts with the offer.
    case SignalUserInteraction
    /// Not applicable
    case CaptureAttributes
}

enum UserInteraction: String, Codable, CaseIterable {
    case ValidationTriggerFailed
    case DropDownItemSelected
    case ThumbnailClick
    case MainImageScrollIconLeftClick
    case MainImageScrollIconRightClick
    case MainImageSwipeLeft
    case MainImageSwipeRight
}

enum UserInteractionContext: String, Codable, CaseIterable {
    case CustomStateValidationTriggerButton
    case CatalogDropDown
    case CatalogImageGallery
}
