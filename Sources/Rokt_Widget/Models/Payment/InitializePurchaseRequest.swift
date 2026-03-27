import Foundation

struct InitializePurchaseRequest {
    let totalUpsellPrice: Decimal
    let currency: String
    let upsellItems: [UpsellItem]
    let fulfillmentDetails: FulfillmentDetails?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "totalUpsellPrice": totalUpsellPrice,
            "currency": currency,
            "upsellItems": upsellItems.map { $0.toDictionary() }
        ]

        if let fulfillmentDetails {
            dict["fulfillmentDetails"] = fulfillmentDetails.toDictionary()
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
