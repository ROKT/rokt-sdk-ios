import Foundation
import DcuiSchema

public class RoktUXEvent {

    /// Triggered when the user engages with the offer
    public class OfferEngagement: RoktUXEvent {
        public let layoutId: String?

        /// Initializes an OfferEngagement event.
        /// - Parameter layoutId: The identifier of the layout.
        init(layoutId: String?) {
            self.layoutId = layoutId
        }
    }

    /// Triggered when the user positively engages with the offer for the first time
    public class FirstPositiveEngagement: RoktUXEvent {
        public var sessionId: String
        public var pageInstanceGuid: String
        public var jwtToken: String
        public let layoutId: String?

        /// Initializes a FirstPositiveEngagement event.
        /// - Parameters:
        ///   - sessionId: The session identifier.
        ///   - pageInstanceGuid: The page instance GUID.
        ///   - jwtToken: The JWT token.
        ///   - layoutId: The identifier of the layout.
        init(sessionId: String, pageInstanceGuid: String, jwtToken: String, layoutId: String?) {
            self.sessionId = sessionId
            self.pageInstanceGuid = pageInstanceGuid
            self.jwtToken = jwtToken
            self.layoutId = layoutId
        }
    }

    /// Triggered when the user positively engages with the offer
    public class PositiveEngagement: RoktUXEvent {
        public let layoutId: String?

        /// Initializes a PositiveEngagement event.
        /// - Parameter layoutId: The identifier of the layout.
        init(layoutId: String?) {
            self.layoutId = layoutId
        }
    }

    /// Triggered when a layout has been rendered and is interactable
    public class LayoutInteractive: RoktUXEvent {
        public let layoutId: String?

        /// Initializes a LayoutInteractive event.
        /// - Parameter layoutId: The identifier of the layout.
        init(layoutId: String?) {
            self.layoutId = layoutId
        }
    }

    /// Triggered when a layout is ready to display but has not rendered content yet
    public class LayoutReady: RoktUXEvent {
        public let layoutId: String?

        /// Initializes a LayoutReady event.
        /// - Parameter layoutId: The identifier of the layout.
        init(layoutId: String?) {
            self.layoutId = layoutId
        }
    }

    /// Triggered when a layout is closed by the user
    public class LayoutClosed: RoktUXEvent {
        public let layoutId: String?

        /// Initializes a LayoutClosed event.
        /// - Parameter layoutId: The identifier of the layout.
        init(layoutId: String?) {
            self.layoutId = layoutId
        }
    }

    /// Triggered when the offer progression reaches the end and no more offers are available to display
    public class LayoutCompleted: RoktUXEvent {
        public let layoutId: String?

        /// Initializes a LayoutCompleted event.
        /// - Parameter layoutId: The identifier of the layout.
        init(layoutId: String?) {
            self.layoutId = layoutId
        }
    }

    /// Triggered when a layout could not be displayed due to some failure
    public class LayoutFailure: RoktUXEvent {
        public let layoutId: String?

        /// Initializes a LayoutFailure event.
        /// - Parameter layoutId: The identifier of the layout.
        init(layoutId: String?) {
            self.layoutId = layoutId
        }
    }

    /// Triggered when a link needs to be opened
    public class OpenUrl: RoktUXEvent {
        public let url: String
        public let id: String
        public let layoutId: String?
        public let type: RoktUXOpenURLType
        public let onClose: ((String) -> Void)?
        public let onError: ((String, Error?) -> Void)?

        /// Initializes an OpenUrl event.
        /// - Parameters:
        ///   - url: The URL to open.
        ///   - id: The identifier associated with the URL.
        ///   - layoutId: The identifier of the layout.
        ///   - type: The type of the URL.
        ///   - onClose: Closure to handle URL close event.
        ///   - onError: Closure to handle URL error event.
        init(url: String,
             id: String,
             layoutId: String?,
             type: RoktUXOpenURLType,
             onClose: @escaping (String) -> Void,
             onError: @escaping (String, Error?) -> Void) {
            self.url = url
            self.id = id
            self.layoutId = layoutId
            self.type = type
            self.onClose = onClose
            self.onError = onError
        }
    }

    public class CartItemInstantPurchase: RoktUXEvent {
        public let layoutId: String
        public let name: String
        public let cartItemId: String
        public let catalogItemId: String
        public let currency: String
        public let description: String
        public let linkedProductId: String?
        public let providerData: String
        public let quantity: Decimal
        public let totalPrice: Decimal?
        public let unitPrice: Decimal?

        init(layoutId: String,
             name: String,
             cartItemId: String,
             catalogItemId: String,
             currency: String,
             description: String,
             linkedProductId: String?,
             providerData: String,
             quantity: Decimal,
             totalPrice: Decimal?,
             unitPrice: Decimal?) {
            self.layoutId = layoutId
            self.name = name
            self.cartItemId = cartItemId
            self.catalogItemId = catalogItemId
            self.currency = currency
            self.description = description
            self.linkedProductId = linkedProductId
            self.providerData = providerData
            self.quantity = quantity
            self.totalPrice = totalPrice
            self.unitPrice = unitPrice
        }
    }

    public class CartItemDevicePay: RoktUXEvent {
        public let layoutId: String
        public let name: String
        public let cartItemId: String
        public let catalogItemId: String
        public let currency: String
        public let description: String
        public let linkedProductId: String?
        public let providerData: String
        public let quantity: Decimal
        public let totalPrice: Decimal?
        public let unitPrice: Decimal?
        public let paymentProvider: PaymentProvider
        /// Backend-provided transaction data (billing / shipping address, supported
        /// payment methods, partner payment reference). `nil` if the offer did not
        /// include transaction data.
        public let transactionData: TransactionData?

        init(layoutId: String,
             name: String,
             cartItemId: String,
             catalogItemId: String,
             currency: String,
             description: String,
             linkedProductId: String?,
             providerData: String,
             quantity: Decimal,
             totalPrice: Decimal?,
             unitPrice: Decimal?,
             paymentProvider: PaymentProvider,
             transactionData: TransactionData?) {
            self.layoutId = layoutId
            self.name = name
            self.cartItemId = cartItemId
            self.catalogItemId = catalogItemId
            self.currency = currency
            self.description = description
            self.linkedProductId = linkedProductId
            self.providerData = providerData
            self.quantity = quantity
            self.totalPrice = totalPrice
            self.unitPrice = unitPrice
            self.paymentProvider = paymentProvider
            self.transactionData = transactionData
        }
    }

    public class CartItemForwardPayment: RoktUXEvent {
        public let layoutId: String
        public let name: String
        public let cartItemId: String
        public let catalogItemId: String
        public let currency: String
        public let description: String
        public let linkedProductId: String?
        public let providerData: String
        public let quantity: Decimal
        public let totalPrice: Decimal?
        public let unitPrice: Decimal?
        /// Backend-provided transaction data (billing / shipping address, supported
        /// payment methods, partner payment reference). `nil` if the offer did not
        /// include transaction data.
        public let transactionData: TransactionData?

        init(layoutId: String,
             name: String,
             cartItemId: String,
             catalogItemId: String,
             currency: String,
             description: String,
             linkedProductId: String?,
             providerData: String,
             quantity: Decimal,
             totalPrice: Decimal?,
             unitPrice: Decimal?,
             transactionData: TransactionData?) {
            self.layoutId = layoutId
            self.name = name
            self.cartItemId = cartItemId
            self.catalogItemId = catalogItemId
            self.currency = currency
            self.description = description
            self.linkedProductId = linkedProductId
            self.providerData = providerData
            self.quantity = quantity
            self.totalPrice = totalPrice
            self.unitPrice = unitPrice
            self.transactionData = transactionData
        }
    }
}
