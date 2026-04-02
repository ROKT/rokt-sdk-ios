import Foundation
import UIKit

/// Orchestrates payment processing by managing registered `PaymentExtension` instances
/// and routing payments to the appropriate extension.
final class PaymentOrchestrator {
    static let devicePayErrorCode = "[DEVICE_PAY]"
    static let paymentPreparationResponseValidationError = "Payment preparation response missing required fields"
    static let paymentPreparationFailedError = "Payment preparation failed"

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
        let replacedExtensions = registeredExtensions.filter { $0.id == paymentExtension.id }
        replacedExtensions.forEach { $0.onUnregister() }
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
        registeredExtensions.filter { $0.supportedMethods.contains(method.wireValue) }
    }

    /// Whether any payment extension is registered.
    var hasRegisteredExtension: Bool {
        !registeredExtensions.isEmpty
    }

    /// All available payment methods across all registered extensions.
    func availablePaymentMethods() -> [PaymentMethodType] {
        let allWireValues = Set(registeredExtensions.flatMap { $0.supportedMethods })
        return allWireValues.compactMap { PaymentMethodType(wireValue: $0) }
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
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        guard let ext = registeredExtensions.first(where: { $0.supportedMethods.contains(method.wireValue) }) else {
            completion(.failed(error: "No payment extension found for method: \(method.wireValue)"))
            return
        }

        // The preparePayment callback bridges the completion-handler pattern
        // to the SDK's backend API call (initializePurchase)
        let preparePayment: (ContactAddress, @escaping (PaymentPreparation?, Error?) -> Void)
            -> Void = { contactAddress, prepareCompletion in
            self.preparePaymentForItem(item: item, cartItemId: cartItemId, contactAddress: contactAddress) { result in
                switch result {
                case .success(let preparation):
                    prepareCompletion(preparation, nil)
                case .failure(let error):
                    prepareCompletion(nil, error)
                }
            }
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

    // periphery:ignore - private; only referenced from processPayment (see periphery note there)
    private func preparePaymentForItem(
        item: PaymentItem,
        cartItemId: String,
        contactAddress: ContactAddress,
        completion: @escaping (Result<PaymentPreparation, Error>) -> Void
    ) {
        let upsellItem = UpsellItem(
            cartItemId: cartItemId,
            catalogItemId: item.id,
            quantity: 1,
            unitPrice: item.amount.decimalValue,
            totalPrice: item.amount.decimalValue,
            currency: item.currency
        )

        let shippingAttributes = ShippingAttributes(from: contactAddress)

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
                        userInfo: [NSLocalizedDescriptionKey: PaymentOrchestrator.paymentPreparationResponseValidationError]
                    )
                    self.apiHelper.sendDiagnostics(
                        message: PaymentOrchestrator.devicePayErrorCode,
                        callStack: PaymentOrchestrator.paymentPreparationResponseValidationError,
                        severity: .warning,
                        additionalInfo: [
                            "clientSecretPresent": response.paymentDetails.clientSecret != nil,
                            "merchantIdPresent": response.paymentDetails.merchantAccountId != nil
                        ]
                    )
                    completion(.failure(validationError))
                    return
                }

                let preparation = PaymentPreparation(
                    clientSecret: clientSecret,
                    merchantId: merchantId
                )
                completion(.success(preparation))
            },
            failure: { error, _, message in
                self.apiHelper.sendDiagnostics(
                    message: PaymentOrchestrator.devicePayErrorCode,
                    callStack: PaymentOrchestrator.paymentPreparationFailedError,
                    severity: .warning,
                    additionalInfo: [
                        "error": error.localizedDescription,
                        "message": message
                    ]
                )
                completion(.failure(error))
            }
        )
    }
}
