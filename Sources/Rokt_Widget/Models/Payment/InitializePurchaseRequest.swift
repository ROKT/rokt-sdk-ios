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
    /// Cart API `paymentMethod` discriminator (lowercase, e.g. `"card"`, `"apple_pay"`,
    /// `"paypal"`, `"afterpay"`). Maps to the protobuf `PaymentMethodType` enum on the backend.
    let paymentMethod: String?
    /// Cart API `paymentProvider` discriminator (lowercase, e.g. `"stripe"`, `"paypal"`,
    /// `"card"`, `"afterpay"`). Pass-through of the upstream DCUI provider so the backend can
    /// disambiguate routing (e.g. stripe-routed apple_pay vs built-in apple_pay).
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
            dict["paymentMethod"] = paymentMethod
        }
        if let paymentProvider {
            dict["paymentProvider"] = paymentProvider
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
