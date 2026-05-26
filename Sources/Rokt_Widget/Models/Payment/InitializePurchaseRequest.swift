import Foundation

/// Request body for Transactions `POST /v2/commerce/purchases` (Initialize Purchase).
/// See `github.com/ROKT/transactions` `apps/api/internal/commerce/handler.go` and `proto/gateway/v1/gateway.proto`.
struct InitializePurchaseRequest {
    let sessionId: String
    let totalUpsellPrice: Decimal
    let currency: String
    let upsellItems: [UpsellItem]
    let fulfillmentDetails: FulfillmentDetails?
    /// PayPal (or other redirect) success URL — mapped to `redirect_urls.return_url`.
    let returnURL: String?
    /// Optional cancel URL — mapped to `redirect_urls.cancel_url`.
    let cancelURL: String?
    /// Cart-style `paymentMethod` token (e.g. `"PAYPAL"`, `"APPLE_PAY"`). Mapped to proto enum strings such as `PAYMENT_METHOD_PAYPAL`.
    let paymentMethod: String?
    /// Legacy cart `paymentProvider` (e.g. `"PayPal"`). Not sent on the Transactions commerce endpoint; the backend infers the PSP from `payment_method`.
    let paymentProvider: String?

    /// JSON body for `POST /v2/commerce/purchases` (protojson field names, snake_case keys).
    func toCommercePurchasesDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "session_id": sessionId,
            "payment_method": Self.commercePaymentMethodEnum(fromCartWire: paymentMethod),
            "line_items": upsellItems.map { $0.toCommerceLineItemDictionary() }
        ]

        if let fulfillmentDetails {
            dict["shipping_details"] = fulfillmentDetails.toCommerceDictionary()
        }

        if let returnURL, let cancelURL {
            dict["redirect_urls"] = [
                "return_url": returnURL,
                "cancel_url": cancelURL
            ]
        }

        return dict
    }

    /// Maps cart `paymentMethod` wire tokens to `gatewaypb.InitializePurchaseRequest.payment_method` JSON enum strings.
    private static func commercePaymentMethodEnum(fromCartWire cartValue: String?) -> String {
        let raw = cartValue?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        if raw.hasPrefix("PAYMENT_METHOD_") {
            return raw
        }
        switch raw {
        case "PAYPAL":
            return "PAYMENT_METHOD_PAYPAL"
        case "APPLE_PAY":
            return "PAYMENT_METHOD_APPLE_PAY"
        case "CARD":
            return "PAYMENT_METHOD_CREDIT_CARD_FORWARD"
        case "AFTERPAY":
            return "PAYMENT_METHOD_AFTERPAY_CLEARPAY"
        default:
            return raw.isEmpty ? "PAYMENT_METHOD_CREDIT_CARD_FORWARD" : raw
        }
    }
}

extension UpsellItem {
    /// Single `line_items[]` entry: `catalog_item_guid` + `quantity` (Transactions commerce contract).
    func toCommerceLineItemDictionary() -> [String: Any] {
        let qty = max(1, Int(truncating: NSDecimalNumber(decimal: quantity)))
        return [
            "catalog_item_guid": catalogItemId,
            "quantity": qty
        ]
    }
}

extension FulfillmentDetails {
    func toCommerceDictionary() -> [String: Any] {
        ["address": shippingAttributes.toCommerceAddressDictionary()]
    }
}

extension ShippingAttributes {
    /// `shipping_details.address` object for `POST /v2/commerce/purchases` (snake_case keys).
    func toCommerceAddressDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "address1": address1,
            "city": city,
            "province_code": state,
            "zip": postalCode
        ]
        let cc = (countryCode?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? country
        dict["country_code"] = cc
        if let firstName { dict["first_name"] = firstName }
        if let lastName { dict["last_name"] = lastName }
        if let companyName { dict["company_name"] = companyName }
        if let address2 { dict["address2"] = address2 }
        return dict
    }
}
