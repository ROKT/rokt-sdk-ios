import Foundation

/// Pre-populated defaults for the Shoppable Ads demo screen.
///
/// Mirrors the structure used by the public `rokt-demo-ios` app so that
/// QA / ops teams get a near-identical sandbox experience in either app.
enum ShoppableAdsDefaults {
    static let tagID = "3068704822624787054"
    static let viewName = "StgRoktShoppableAds"
    static let stripePublishableKey = ""
    static let applePayMerchantId =
        Bundle.main.object(forInfoDictionaryKey: "ApplePayMerchantID") as? String ?? "merchant.rokt.test"

    static let attributes: [(key: String, value: String)] = [
        ("email", "jenny.smith@example.com"),
        ("firstname", "Jenny"),
        ("lastname", "Smith"),
        ("confirmationref", "ORD-12345"),
        ("country", "US"),
        ("sandbox", "true"),
        ("shippingaddress1", "123 Main St"),
        ("shippingaddress2", "Apt 4B"),
        ("shippingcity", "New York"),
        ("shippingstate", "NY"),
        ("shippingzipcode", "10001"),
        ("shippingcountry", "US"),
        ("billingzipcode", "07762"),
        ("paymenttype", "ApplePay"),
        ("last4digits", "4444")
    ]
}
