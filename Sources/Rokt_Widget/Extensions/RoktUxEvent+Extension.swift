internal import RoktUXHelper

internal extension RoktUXEvent {
    var mapToRoktEvent: RoktEvent? {
        if let event = self as? RoktUXEvent.OfferEngagement {
            return RoktEvent.OfferEngagement(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.FirstPositiveEngagement {
            return RoktEvent.FirstPositiveEngagement(
                sessionId: event.sessionId,
                pageInstanceGuid: event.pageInstanceGuid,
                jwtToken: event.jwtToken,
                identifier: event.layoutId
            )
        } else if let event = self as? RoktUXEvent.OpenUrl {
            return RoktEvent.OpenUrl(identifier: event.layoutId, url: event.url)
        } else if let event = self as? RoktUXEvent.PositiveEngagement {
            return RoktEvent.PositiveEngagement(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.LayoutInteractive {
            return RoktEvent.PlacementInteractive(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.LayoutReady {
            return RoktEvent.PlacementReady(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.LayoutClosed {
            return RoktEvent.PlacementClosed(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.LayoutCompleted {
            return RoktEvent.PlacementCompleted(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.LayoutFailure {
            return RoktEvent.PlacementFailure(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.CartItemInstantPurchase {
            return RoktEvent.CartItemInstantPurchase(uxEvent: event)
        } else {
            return nil
        }
    }
}
