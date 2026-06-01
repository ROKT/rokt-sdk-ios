import Foundation

/// Transaction-level data decoded from the backend experience response.
///
/// Exposed publicly so the Rokt SDK (and partner apps, via `RoktUXEvent.CartItemDevicePay`)
/// can read the pre-collected billing / shipping / supported-methods information the
/// backend provides, instead of requiring partners to re-supply these as attributes.
public struct TransactionData: Codable {
    public let shippingAddress: Address?
    public let billingAddress: Address?
    public let paymentType: String?
    public let supportedPaymentMethods: [PaymentMethod]?
    public let isPartnerManagedPurchase: Bool
    public let partnerPaymentReference: String?
    public let confirmationRef: String?
    public let metadata: [String: String]
}

public struct PaymentMethod: Codable {
    public enum MethodType: String, Codable {
        case unspecified = "UNSPECIFIED"
        case other = "OTHER"
        case card = "CARD"
        case applePay = "APPLE_PAY"
        case paypal = "PAYPAL"
        case googlePay = "GOOGLE_PAY"
        case afterpay = "AFTERPAY"
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = MethodType(rawValue: raw) ?? .unknown
        }
    }

    public let type: MethodType
}

public struct Address: Codable {
    public let name: String
    public let address1: String
    public let address2: String?
    public let city: String
    public let state: String
    public let stateCode: String
    public let country: String
    public let countryCode: String
    public let zip: String?
}
