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
    /// Cart API `paymentMethodType` discriminator. PascalCase tokens matching the cart-api
    /// `PaymentMethodType` member names (`"Card"`, `"ApplePay"`, `"Paypal"`, `"Afterpay"`) —
    /// the same values DCUI returns in `paymentProvider`, so the method is sent back in the
    /// vocabulary it arrives in. Accepted by the cart-api `InitializePurchaseApiRequest`
    /// contract (Newtonsoft matches enum member names case-insensitively). Distinct from the
    /// short `TransactionData.type` tokens (`"CARD"`, `"APPLE_PAY"`, …); note `"APPLE_PAY"`
    /// itself would not deserialize into the cart-api enum.
    let paymentMethodType: String?
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
        if let paymentMethodType {
            dict["paymentMethodType"] = paymentMethodType
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
