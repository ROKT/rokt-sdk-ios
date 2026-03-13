import Foundation
internal import RoktUXHelper

@objc public class RoktEvent: NSObject {

    @objc public class InitComplete: RoktEvent {
        @objc public let success: Bool

        init(success: Bool) {
            self.success = success
        }
    }

    @objc public class ShowLoadingIndicator: RoktEvent {}

    @objc public class HideLoadingIndicator: RoktEvent {}

    @objc public class PlacementInteractive: RoktEvent {
        @objc public let identifier: String?

        init(identifier: String?) {
            self.identifier = identifier
        }
    }

    @objc public class PlacementReady: RoktEvent {
        @objc public let identifier: String?

        init(identifier: String?) {
            self.identifier = identifier
        }
    }

    @objc public class OfferEngagement: RoktEvent {
        @objc public let identifier: String?

        init(identifier: String?) {
            self.identifier = identifier
        }
    }

    @objc public class OpenUrl: RoktEvent {
        @objc public let identifier: String?
        @objc public let url: String

        init(identifier: String?, url: String) {
            self.url = url
            self.identifier = identifier
        }
    }

    @objc public class PositiveEngagement: RoktEvent {
        @objc public let identifier: String?

        init(identifier: String?) {
            self.identifier = identifier
        }
    }

    @objc public class PlacementClosed: RoktEvent {
        @objc public let identifier: String?

        init(identifier: String?) {
            self.identifier = identifier
        }
    }

    @objc public class PlacementCompleted: RoktEvent {
        @objc public let identifier: String?

        init(identifier: String?) {
            self.identifier = identifier
        }
    }

    @objc public class PlacementFailure: RoktEvent {
        @objc public let identifier: String?

        init(identifier: String?) {
            self.identifier = identifier
        }
    }

    @objc public class FirstPositiveEngagement: RoktEvent {
        private var sessionId: String
        private var pageInstanceGuid: String
        private var jwtToken: String
        @objc public let identifier: String?

        init(sessionId: String, pageInstanceGuid: String, jwtToken: String, identifier: String?) {
            self.sessionId = sessionId
            self.pageInstanceGuid = pageInstanceGuid
            self.jwtToken = jwtToken
            self.identifier = identifier
        }

        @objc public func setFulfillmentAttributes(attributes: [String: String]) {
            RoktAPIHelper.sendEvent(
                eventRequest: EventRequest(
                    sessionId: sessionId,
                    eventType: .CaptureAttributes,
                    parentGuid: sessionId,
                    attributes: attributes,
                    pageInstanceGuid: pageInstanceGuid,
                    jwtToken: jwtToken
                )
            )
        }
    }

    @objc public class CartItemInstantPurchase: RoktEvent {
        @objc public let identifier: String
        @objc public let name: String?
        @objc public let cartItemId: String
        @objc public let catalogItemId: String
        @objc public let currency: String
        private let _description: String
        @objc public override var description: String {
            _description
        }
        @objc public let linkedProductId: String?
        @objc public let providerData: String
        @objc public let quantity: NSDecimalNumber?
        @objc public let totalPrice: NSDecimalNumber?
        @objc public let unitPrice: NSDecimalNumber?

        init(identifier: String,
             name: String,
             cartItemId: String,
             catalogItemId: String,
             currency: String,
             description: String,
             linkedProductId: String?,
             providerData: String,
             quantity: Decimal?,
             totalPrice: Decimal?,
             unitPrice: Decimal?) {
            self.identifier = identifier
            self.name = name
            self.cartItemId = cartItemId
            self.catalogItemId = catalogItemId
            self.currency = currency
            self._description = description
            self.linkedProductId = linkedProductId
            self.providerData = providerData
            self.quantity = quantity.map { NSDecimalNumber(decimal: $0) }
            self.totalPrice = totalPrice.map { NSDecimalNumber(decimal: $0) }
            self.unitPrice = unitPrice.map { NSDecimalNumber(decimal: $0) }
        }

        convenience init(uxEvent: RoktUXEvent.CartItemInstantPurchase) {
            self.init(
                identifier: uxEvent.layoutId,
                name: uxEvent.name,
                cartItemId: uxEvent.cartItemId,
                catalogItemId: uxEvent.catalogItemId,
                currency: uxEvent.currency,
                description: uxEvent.description,
                linkedProductId: uxEvent.linkedProductId,
                providerData: uxEvent.providerData,
                quantity: uxEvent.quantity,
                totalPrice: uxEvent.totalPrice,
                unitPrice: uxEvent.unitPrice
            )
        }
    }

    /// An event that is emitted when the height of an embedded placement changes.
    /// This event is useful for dynamically adjusting the container view's height
    /// to accommodate the Rokt placement content.
    ///
    /// - Note: This event is only emitted for embedded placements
    @objc public class EmbeddedSizeChanged: RoktEvent {
        /// The identifier of the placement whose height has changed
        @objc public let identifier: String
        /// The new height of the placement
        @objc public let updatedHeight: CGFloat

        init(identifier: String, updatedHeight: CGFloat) {
            self.identifier = identifier
            self.updatedHeight = updatedHeight
        }
    }
}
