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
    /// Cart API `paymentMethod` discriminator (UPPERCASE, e.g. `"CARD"`, `"APPLE_PAY"`,
    /// `"PAYPAL"`, `"AFTERPAY"`). Matches the `LayoutPaymentMethodType` enum (web SDK) and
    /// the `PaymentMethod.MethodType` rawValues decoded from backend `transactionData`.
    let paymentMethod: String?
    /// Cart API `paymentProvider` discriminator (PascalCase, e.g. `"Stripe"`, `"PayPal"`,
    /// `"Card"`, `"Afterpay"`, `"ApplePay"`). Pass-through of the DcuiSchema `PaymentProvider`
    /// enum so the backend can disambiguate routing (e.g. Stripe-routed ApplePay vs built-in
    /// ApplePay).
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
