import Foundation

public enum RoktUXPlacementLayoutCode: String, Codable, RoktUXCaseIterableDefaultLast {
    case lightboxLayout = "MobileSdk.LightboxLayout"
    case embeddedLayout = "MobileSdk.EmbeddedLayout"
    case overlayLayout = "MobileSdk.OverlayLayout"
    case bottomSheetLayout = "MobileSdk.BottomSheetLayout"
    case unknown
}
