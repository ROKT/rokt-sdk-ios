import Foundation

/// PayPal-specific payload returned when `payment_provider.paypal` is present on the commerce initialize purchase response.
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

extension InitializePurchaseResponse {
    /// Decodes the `Purchase` JSON returned by `POST /v2/commerce/purchases` (`writePurchaseJSON` in Transactions `apps/api`).
    static func decodeFromCommercePurchasesAPI(data: Data) throws -> InitializePurchaseResponse {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = json as? [String: Any] else {
            throw NSError(
                domain: "RoktSDK",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected initialize purchase response"]
            )
        }

        let status = (root["status"] as? String)?.uppercased() ?? ""
        let success = status != "FAILED"

        let totals = root["totals"] as? [String: Any] ?? [:]
        let totalUpsellPrice = decimal(from: totals["total_amount"])
        let shippingCost = decimal(from: totals["shipping_fee"])
        let tax = decimal(from: totals["tax"])
        let currency = (totals["currency"] as? String) ?? "USD"

        let display = root["display_details"] as? [String: Any]
        let merchantName = display?["merchant_name"] as? String

        let paymentProvider = root["payment_provider"] as? [String: Any]
        let kind = (paymentProvider?["kind"] as? String) ?? "stripe"
        let stripe = paymentProvider?["stripe"] as? [String: Any]
        let clientSecret = stripe?["client_secret"] as? String
        let accountId = stripe?["account_id"] as? String

        var paypalData: InitializePurchasePayPalData?
        if let paypal = paymentProvider?["paypal"] as? [String: Any],
           let orderId = paypal["order_id"] as? String,
           let approvalUrl = paypal["approval_url"] as? String,
           !orderId.isEmpty,
           !approvalUrl.isEmpty {
            paypalData = InitializePurchasePayPalData(orderId: orderId, approvalUrl: approvalUrl)
        }

        let paymentDetails = PaymentDetails(
            gateway: kind,
            merchantName: merchantName,
            merchantAccountId: accountId,
            paymentIntentId: nil,
            clientSecret: clientSecret,
            shippingCost: shippingCost,
            tax: tax,
            totalAmount: totalUpsellPrice
        )

        return InitializePurchaseResponse(
            success: success,
            totalUpsellPrice: totalUpsellPrice,
            currency: currency,
            upsellItems: [],
            paymentDetails: paymentDetails,
            paypalData: paypalData
        )
    }

    private static func decimal(from value: Any?) -> Decimal {
        switch value {
        case let s as String:
            return Decimal(string: s) ?? 0
        case let n as NSNumber:
            return n.decimalValue
        default:
            return 0
        }
    }
}
