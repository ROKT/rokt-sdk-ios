import Foundation

private let BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY = "paymentExtensionRegistered"

/// Enriches experience requests with whether a payment extension has been registered.
///
/// Downstream systems use this attribute to determine whether Shoppable Ads requiring
/// a payment extension can be presented to the user.
///
/// - Returns:
///  - `"true"` for `paymentExtensionActivated` when a payment extension is registered.
///  - `"false"` for `paymentExtensionActivated` when no payment extension is registered.
class PaymentExtensionAttributeEnricher: AttributeEnricher {
    private let provider: () -> Bool

    init(provider: @escaping () -> Bool) {
        self.provider = provider
    }

    func enrich(config: RoktConfig?) -> [String: String] {
        return [BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY: String(provider())]
    }
}
