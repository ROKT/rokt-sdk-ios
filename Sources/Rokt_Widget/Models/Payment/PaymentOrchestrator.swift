import Foundation
import UIKit
import RoktContracts

/// Orchestrates payment processing by managing registered `PaymentExtension` instances
/// and routing payments to the appropriate extension.
///
/// PayPal is handled by a **built-in** flow that does not use ``PaymentExtension`` registration.
/// Other methods continue to require a registered extension that advertises the matching wire value.
final class PaymentOrchestrator {
    static let devicePayErrorCode = "[DEVICE_PAY]"
    static let paymentPreparationResponseValidationError = "Payment preparation response missing required fields"
    static let paymentPreparationFailedError = "Payment preparation failed"
    /// Cart prepare succeeded but the response did not include a PayPal approval URL (`paypalData.approvalUrl`).
    static let payPalApprovalURLMissingMessage =
        "PayPal approval URL was not returned; cannot start checkout."
    /// Built-in PayPal uses ``PaymentContext/returnURL`` to detect completion when PayPal redirects after approval.
    static let payPalReturnURLMissingMessage =
        "PaymentContext.returnURL is required for PayPal checkout."

    private var registeredExtensions: [PaymentExtension] = []
    private let apiHelper: RoktAPIHelper.Type
    private let payPalApprovalPresenter: PayPalApprovalPresenting
    /// Active built-in PayPal session so ``handleURLCallback(with:)`` can complete checkout when the return/cancel **deep link** opens the host app.
    private var activePayPalCheckout: PayPalCheckoutCoordinator?

    init(
        apiHelper: RoktAPIHelper.Type = RoktAPIHelper.self,
        payPalApprovalPresenter: PayPalApprovalPresenting = PayPalApprovalWebPresenter()
    ) {
        self.apiHelper = apiHelper
        self.payPalApprovalPresenter = payPalApprovalPresenter
    }

    // MARK: - Registration

    /// Register a payment extension with configuration.
    ///
    /// - Parameters:
    ///   - paymentExtension: The extension to register (e.g. RoktPaymentExtension)
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

    /// All available payment methods across all registered extensions, plus built-in PayPal.
    func availablePaymentMethods() -> [PaymentMethodType] {
        var methods = Set(
            registeredExtensions.flatMap { $0.supportedMethods }.compactMap { PaymentMethodType(wireValue: $0) }
        )
        methods.insert(.paypal)
        return PaymentMethodType.allCases.filter { methods.contains($0) }
    }

    /// Forward a URL to the built-in PayPal handler first, then each registered extension until one claims it.
    ///
    /// Used for redirect-based payment methods (e.g. Afterpay, PayPal) that return to the host app
    /// via a custom URL scheme. Iteration stops at the first handler that returns `true`.
    ///
    /// - Parameter url: The URL received by the host app.
    /// - Returns: `true` if the built-in PayPal handler or any registered extension recognized and handled the URL.
    @discardableResult
    func handleURLCallback(with url: URL) -> Bool {
        if handleBuiltInPayPalURLIfNeeded(url) {
            return true
        }
        return registeredExtensions.contains { $0.handleURLCallback?(with: url) ?? false }
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
        context: PaymentContext,
        cartItemId: String,
        from viewController: UIViewController,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        if method == .paypal {
            processBuiltInPayPalPayment(
                item: item,
                context: context,
                cartItemId: cartItemId,
                from: viewController,
                completion: completion
            )
            return
        }

        guard let ext = registeredExtensions.first(where: { $0.supportedMethods.contains(method.wireValue) }) else {
            completion(.failed(error: "No payment extension found for method: \(method.wireValue)"))
            return
        }

        // The preparePayment callback bridges the completion-handler pattern
        // to the SDK's backend API call (initializePurchase)
        let preparePayment: (ContactAddress, @escaping (PaymentPreparation?, Error?) -> Void)
            -> Void = { contactAddress, prepareCompletion in
            self.preparePaymentForItem(
                item: item,
                cartItemId: cartItemId,
                contactAddress: contactAddress,
                returnURL: nil,
                cancelURL: nil
            ) { result in
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
            context: context,
            from: viewController,
            preparePayment: preparePayment,
            completion: completion
        )
    }

    // MARK: - Built-in PayPal (no PaymentExtension)

    /// Entry point for PayPal device pay. Does not consult ``registeredExtensions``.
    ///
    /// Runs the same cart ``initializePurchase`` preparation as extension-based flows, passing
    /// ``PaymentContext/returnURL`` and ``PaymentContext/cancelURL`` through to the API body when present.
    /// For device pay from a placement, ``Rokt/setBuiltInPayPalRedirectURLScheme(_:)`` supplies those URLs on ``PaymentContext``.
    /// After cart prepare, presents PayPal's hosted approval URL (same role as the Orders API `approve` link).
    private func processBuiltInPayPalPayment(
        item: PaymentItem,
        context: PaymentContext,
        cartItemId: String,
        from viewController: UIViewController,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        let contactAddress = Self.contactAddressForInitializePurchase(context: context)
        preparePaymentForItem(
            item: item,
            cartItemId: cartItemId,
            contactAddress: contactAddress,
            returnURL: context.returnURL,
            cancelURL: context.cancelURL
        ) { result in
            switch result {
            case .success(let preparation):
                Self.verboseLogBuiltInPayPalPaymentPreparation(preparation)
                guard let approvalString = preparation.approvalUrl?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !approvalString.isEmpty,
                      let approvalURL = URL(string: approvalString)
                else {
                    DispatchQueue.main.async {
                        completion(.failed(error: Self.payPalApprovalURLMissingMessage))
                    }
                    return
                }
                guard let returnURL = context.returnURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !returnURL.isEmpty,
                      URL(string: returnURL) != nil
                else {
                    DispatchQueue.main.async {
                        completion(.failed(error: Self.payPalReturnURLMissingMessage))
                    }
                    return
                }
                let sanitizedCancelURL = Self.nonEmptyTrimmed(context.cancelURL)
                let coordinator = PayPalCheckoutCoordinator(
                    returnURLString: returnURL,
                    cancelURLString: sanitizedCancelURL,
                    completion: { [weak self] result in
                        self?.activePayPalCheckout = nil
                        completion(result)
                    }
                )
                self.activePayPalCheckout = coordinator
                self.payPalApprovalPresenter.presentPayPalApproval(
                    approvalURL: approvalURL,
                    from: viewController,
                    checkoutCoordinator: coordinator
                )
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failed(error: error.localizedDescription))
                }
            }
        }
    }

    private static func nonEmptyTrimmed(_ string: String?) -> String? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Prefer shipping, then billing, for cart shipping attributes; otherwise a minimal placeholder.
    private static func contactAddressForInitializePurchase(context: PaymentContext) -> ContactAddress {
        if let shipping = context.shippingAddress {
            return shipping
        }
        if let billing = context.billingAddress {
            return billing
        }
        return ContactAddress(name: "", email: "")
    }

    /// Logs built-in PayPal ``PaymentPreparation`` fields at verbose level. Does not log raw ``PaymentPreparation/clientSecret``
    /// or full approval URLs (may contain tokens in the query).
    private static func verboseLogBuiltInPayPalPaymentPreparation(_ preparation: PaymentPreparation) {
        let approvalSummary: String = {
            guard let raw = preparation.approvalUrl, !raw.isEmpty else { return "nil" }
            guard let components = URLComponents(string: raw) else {
                return "<unparseable len=\(raw.count)>"
            }
            let hostPath = "\(components.scheme ?? "")://\(components.host ?? "")\(components.path)"
            let queryCount = components.queryItems?.count ?? 0
            return "\(hostPath) queryParameterCount=\(queryCount)"
        }()

        RoktLogger.shared.verbose(
            "\(Self.devicePayErrorCode) Built-in PayPal PaymentPreparation " +
                "clientSecret=<redacted characterCount=\(preparation.clientSecret.count)> " +
                "merchantId=\(preparation.merchantId) " +
                "totalAmount=\(preparation.totalAmount) " +
                "shippingCost=\(preparation.shippingCost) " +
                "tax=\(preparation.tax) " +
                "approvalUrl=\(approvalSummary)"
        )
    }

    /// When ``PaymentContext/returnURL`` is a **deep link**, PayPal may complete checkout by opening the host app;
    /// forward those URLs to the active ``PayPalCheckoutCoordinator``.
    private func handleBuiltInPayPalURLIfNeeded(_ url: URL) -> Bool {
        activePayPalCheckout?.handleDeepLinkReturn(url) ?? false
    }

    // MARK: - Private

    private func preparePaymentForItem(
        item: PaymentItem,
        cartItemId: String,
        contactAddress: ContactAddress,
        returnURL: String? = nil,
        cancelURL: String? = nil,
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
            returnURL: returnURL,
            cancelURL: cancelURL,
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
                    merchantId: merchantId,
                    totalAmount: response.paymentDetails.totalAmount,
                    shippingCost: response.paymentDetails.shippingCost,
                    tax: response.paymentDetails.tax,
                    approvalUrl: response.paypalData?.approvalUrl
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
