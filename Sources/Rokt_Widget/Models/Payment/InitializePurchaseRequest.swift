import Foundation

struct InitializePurchaseRequest {
    let totalUpsellPrice: Decimal
    let currency: String
    let upsellItems: [UpsellItem]
    let fulfillmentDetails: FulfillmentDetails?
    /// PayPal (or other redirect) success URL for the cart initialize-purchase API.
    let returnURL: String?
    /// Optional cancel URL for the cart initialize-purchase API.
    let cancelURL: String?
    /// Cart API payment method discriminator (e.g. built-in PayPal: `"PAYPAL"`).
    let paymentMethod: String?
    /// Cart API payment provider discriminator (e.g. built-in PayPal: `"PAYPAL"`).
    let paymentProvider: String?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "totalUpsellPrice": totalUpsellPrice,
            "currency": currency,
            "upsellItems": upsellItems.map { $0.toDictionary() }
        ]

        if let fulfillmentDetails {
            dict["fulfillmentDetails"] = fulfillmentDetails.toDictionary()
        }
        if let returnURL {
            dict["returnURL"] = returnURL
        }
        if let cancelURL {
            dict["cancelURL"] = cancelURL
        }
        if let paymentMethod {
            dict["payment_method"] = paymentMethod
        }
        if let paymentProvider {
            dict["payment_provider"] = paymentProvider
        }

        return dict
    }
}

struct FulfillmentDetails {
    let shippingAttributes: ShippingAttributes

    func toDictionary() -> [String: Any] {
        ["shippingAttributes": shippingAttributes.toDictionary()]
    }
}
