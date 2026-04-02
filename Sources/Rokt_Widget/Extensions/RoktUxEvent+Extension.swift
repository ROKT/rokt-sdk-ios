import Foundation
internal import RoktUXHelper

internal extension RoktUXEvent {
    var mapToRoktEvent: RoktEvent? {
        if let event = self as? RoktUXEvent.OfferEngagement {
            return RoktEvent.OfferEngagement(identifier: event.layoutId)
        } else if let event = self as? RoktUXEvent.FirstPositiveEngagement {
            let fpe = RoktEvent.FirstPositiveEngagement(identifier: event.layoutId)
            fpe.setFulfillmentAttributes = { attributes in
                RoktAPIHelper.sendEvent(
                    eventRequest: EventRequest(
                        sessionId: event.sessionId,
                        eventType: .CaptureAttributes,
                        parentGuid: event.sessionId,
                        attributes: attributes,
                        pageInstanceGuid: event.pageInstanceGuid,
                        jwtToken: event.jwtToken
                    )
                )
            }
            return fpe
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
            return RoktEvent.CartItemInstantPurchase(
                identifier: event.layoutId,
                name: event.name,
                cartItemId: event.cartItemId,
                catalogItemId: event.catalogItemId,
                currency: event.currency,
                description: event.description,
                linkedProductId: event.linkedProductId,
                providerData: event.providerData,
                quantity: NSDecimalNumber(decimal: event.quantity),
                totalPrice: event.totalPrice.map { NSDecimalNumber(decimal: $0) },
                unitPrice: event.unitPrice.map { NSDecimalNumber(decimal: $0) }
            )
        } else if let event = self as? RoktUXEvent.CartItemDevicePay {
            return RoktEvent.CartItemDevicePay(
                identifier: event.layoutId,
                catalogItemId: event.catalogItemId,
                cartItemId: event.cartItemId,
                paymentProvider: event.paymentProvider.rawValue
            )
        } else {
            return nil
        }
    }
}
