import Foundation
import UIKit

/// Orchestrates payment processing by managing registered `PaymentExtension` instances
/// and routing payments to the appropriate extension.
final class PaymentOrchestrator {
    private var registeredExtensions: [PaymentExtension] = []
    private let apiHelper: RoktAPIHelper.Type

    init(apiHelper: RoktAPIHelper.Type = RoktAPIHelper.self) {
        self.apiHelper = apiHelper
    }

    // MARK: - Registration

    /// Register a payment extension with configuration.
    ///
    /// - Parameters:
    ///   - paymentExtension: The extension to register (e.g. RoktStripePaymentExtension)
    ///   - config: Configuration parameters (e.g. ["stripeKey": "pk_live_..."])
    /// - Returns: `true` if registration succeeded.
    @discardableResult
    func register(_ paymentExtension: PaymentExtension, config: [String: String]) -> Bool {
        // Remove any previously registered extension with the same id
        registeredExtensions.removeAll { $0.id == paymentExtension.id }

        guard paymentExtension.onRegister(parameters: config) else {
            return false
        }

        registeredExtensions.append(paymentExtension)
        return true
    }

    /// Look up a registered extension by id.
    func paymentExtension(id: String) -> PaymentExtension? {
        registeredExtensions.first { $0.id == id }
    }

    /// Find all registered extensions supporting a given payment method.
    func paymentExtensions(supporting method: PaymentMethodType) -> [PaymentExtension] {
        registeredExtensions.filter { $0.supportedMethods.contains(method) }
    }

    /// Whether any payment extension is registered.
    var hasRegisteredExtension: Bool {
        !registeredExtensions.isEmpty
    }

    /// All available payment methods across all registered extensions.
    func availablePaymentMethods() -> [PaymentMethodType] {
        Array(Set(registeredExtensions.flatMap { $0.supportedMethods }))
    }

    // MARK: - Payment Processing

    /// Process a payment using the first registered extension that supports the given method.
    ///
    /// - Parameters:
    ///   - method: The payment method to use (e.g. `.applePay`)
    ///   - item: The item being purchased (from RoktContracts)
    ///   - cartItemId: The backend cart item ID (format `"v1:uuid:canal"`)
    ///   - viewController: The view controller to present the payment sheet from
    ///   - completion: Called with the payment result
    func processPayment(
        method: PaymentMethodType,
        item: PaymentItem,
        cartItemId: String,
        from viewController: UIViewController,
        completion: @escaping (PaymentResult) -> Void
    ) {
        guard let ext = registeredExtensions.first(where: { $0.supportedMethods.contains(method) }) else {
            completion(.failed(error: "No payment extension found for method: \(method.rawValue)"))
            return
        }

        // The preparePayment callback bridges the async/throws contract pattern
        // to the SDK's backend API call (initializePurchase)
        let preparePayment: @Sendable (ContactAddress) async throws -> PaymentPreparation = { contactAddress in
            try await self.preparePaymentForItem(item: item, cartItemId: cartItemId, contactAddress: contactAddress)
        }

        ext.presentPaymentSheet(
            item: item,
            method: method,
            from: viewController,
            preparePayment: preparePayment,
            completion: completion
        )
    }

    // MARK: - Private

    private func preparePaymentForItem(
        item: PaymentItem,
        cartItemId: String,
        contactAddress: ContactAddress
    ) async throws -> PaymentPreparation {
        let upsellItem = UpsellItem(
            cartItemId: cartItemId,
            catalogItemId: item.id,
            quantity: 1,
            unitPrice: item.amount,
            totalPrice: item.amount,
            currency: item.currency
        )

        let shippingAttributes = ShippingAttributes(from: contactAddress)

        return try await withCheckedThrowingContinuation { continuation in
            apiHelper.initializePurchase(
                upsellItems: [upsellItem],
                shippingAttributes: shippingAttributes,
                success: { response in
                    guard let clientSecret = response.paymentDetails.clientSecret,
                          let merchantId = response.paymentDetails.merchantAccountId,
                          !clientSecret.isEmpty,
                          !merchantId.isEmpty
                    else {
                        let validationError = NSError(
                            domain: "RoktSDK",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: kPaymentPreparationResponseValidationError]
                        )
                        apiHelper.sendDiagnostics(
                            message: kDevicePayErrorCode,
                            callStack: kPaymentPreparationResponseValidationError,
                            severity: .warning,
                            additionalInfo: [
                                "clientSecretPresent": response.paymentDetails.clientSecret != nil,
                                "merchantIdPresent": response.paymentDetails.merchantAccountId != nil
                            ]
                        )
                        continuation.resume(throwing: validationError)
                        return
                    }

                    let preparation = PaymentPreparation(
                        clientSecret: clientSecret,
                        merchantId: merchantId
                    )
                    continuation.resume(returning: preparation)
                },
                failure: { error, _, message in
                    apiHelper.sendDiagnostics(
                        message: kDevicePayErrorCode,
                        callStack: kApplePayPaymentPreparationError,
                        severity: .warning,
                        additionalInfo: [
                            "error": error.localizedDescription,
                            "message": message
                        ]
                    )
                    continuation.resume(throwing: error)
                }
            )
        }
    }
}
