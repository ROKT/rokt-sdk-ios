import Foundation
import RoktContracts

private let BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY = "paymentExtensionRegistered"
private let BE_AVAILABLE_PAYMENT_METHODS_KEY = "availablePaymentMethods"

/// Enriches experience requests with payment extension availability.
///
/// Downstream systems use these attributes to determine whether Shoppable Ads requiring
/// payment handling can be presented to the user.
///
/// - Returns:
///  - `"true"` for `paymentExtensionRegistered` when a payment extension is registered.
///  - `"false"` for `paymentExtensionRegistered` when no payment extension is registered.
///  - Comma-separated method wire values for `availablePaymentMethods`.
class PaymentExtensionAttributeEnricher: AttributeEnricher {
    private let provider: () -> Bool
    private let availablePaymentMethodsProvider: () -> [PaymentMethodType]

    init(
        provider: @escaping () -> Bool,
        availablePaymentMethodsProvider: @escaping () -> [PaymentMethodType]
    ) {
        self.provider = provider
        self.availablePaymentMethodsProvider = availablePaymentMethodsProvider
    }

    func enrich(config: RoktConfig?) -> [String: String] {
        return [
            BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY: String(provider()),
            BE_AVAILABLE_PAYMENT_METHODS_KEY: availablePaymentMethodsProvider()
                .map(\.wireValue)
                .joined(separator: ",")
        ]
    }
}
