import Foundation

struct InitializePurchaseResponse: Decodable {
    let success: Bool
    let totalUpsellPrice: Decimal
    let currency: String
    let upsellItems: [UpsellItem]
    let paymentDetails: PaymentDetails
}

struct PaymentDetails: Decodable {
    let gateway: String
    let merchantName: String?
    let merchantAccountId: String?
    let paymentIntentId: String?
    let clientSecret: String?
    let shippingCost: Decimal
    let tax: Decimal
    let totalAmount: Decimal
}
