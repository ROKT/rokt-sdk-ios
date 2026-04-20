import Foundation

struct PurchaseRequest {
    let totalUpsellPrice: Decimal
    let currency: String
    let upsellItems: [UpsellItem]
    let paymentDetails: PurchasePaymentDetails
    let fulfillmentDetails: FulfillmentDetails?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "totalUpsellPrice": totalUpsellPrice,
            "currency": currency,
            "upsellItems": upsellItems.map { $0.toDictionary() },
            "paymentDetails": paymentDetails.toDictionary()
        ]

        if let fulfillmentDetails {
            dict["fulfillmentDetails"] = fulfillmentDetails.toDictionary()
        }

        return dict
    }
}

struct PurchasePaymentDetails {
    let token: String?
    let partnerPaymentReference: String?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let token {
            dict["token"] = token
        }
        if let partnerPaymentReference {
            dict["partnerPaymentReference"] = partnerPaymentReference
        }
        return dict
    }
}
