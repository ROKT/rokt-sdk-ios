import Foundation

/// PayPal-specific payload returned by the cart initialize-purchase API when applicable.
struct InitializePurchasePayPalData: Decodable, Equatable {
    let orderId: String
    let approvalUrl: String
}

struct InitializePurchaseResponse: Decodable {
    let success: Bool
    let totalUpsellPrice: Decimal
    let currency: String
    let upsellItems: [UpsellItem]
    let paymentDetails: PaymentDetails
    /// Present when the backend returns PayPal order details for redirect-based checkout.
    let paypalData: InitializePurchasePayPalData?
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
