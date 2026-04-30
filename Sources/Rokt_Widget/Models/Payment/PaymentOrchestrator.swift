import Foundation
import UIKit
import RoktContracts

/// Layout context and confirmation hook for built-in **two-step device pay** flows (PayPal, Card).
///
/// Used to drive ``RoktUX/devicePayShowConfirmation`` from the orchestrator after Step-1
/// (`initialize-purchase`) resolves, so the layout can transition to the Step-2 confirm button.
struct BuiltInTwoStepDevicePaySession {
    let layoutId: String
    let catalogItemId: String
    let showConfirmation: (_ layoutId: String, _ catalogItemId: String, _ catalogRuntimeData: [String: String]) -> Void
}

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
    /// Cart `initialize-purchase` body `payment_method` / `payment_provider` for built-in PayPal.
    private static let builtInPayPalInitializePurchaseMethod = "PAYPAL"
    private static let builtInPayPalInitializePurchaseProvider = "PAYPAL"

    private static let pendingBuiltInTwoStepLock = NSLock()

    /// PayPal Step-1 cache: WebView context + deferred Step-1 completion fired on Step-2 resolve.
    private struct PendingBuiltInPayPalWebCheckout {
        weak var owner: PaymentOrchestrator?
        let approvalURL: URL
        let returnURLString: String
        let cancelURLString: String?
        weak var presentingViewController: UIViewController?
        let completion: (PaymentSheetResult) -> Void
    }

    /// Card Step-1 cache: just the deferred completion. Step-2 dispatch lives in
    /// ``RoktInternalImplementation.handleForwardPayment`` (POST `/v1/cart/purchase`); the
    /// orchestrator only holds the completion so it can fire alongside ``forwardPaymentFinalized``.
    private struct PendingBuiltInCardCheckout {
        weak var owner: PaymentOrchestrator?
        let completion: (PaymentSheetResult) -> Void
    }

    private enum PendingBuiltInTwoStepCheckout {
        case paypal(PendingBuiltInPayPalWebCheckout)
        case card(PendingBuiltInCardCheckout)
    }

    private static var pendingBuiltInTwoStepCheckout: PendingBuiltInTwoStepCheckout?

    static let builtInPayPalMissingDeferredSessionMessage =
        "Built-in PayPal device pay requires a layout session for confirmation (device pay hook)."

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
    ///   - builtInPayPalDevicePaySession: For built-in PayPal **device pay** only; drives ``RoktUX/devicePayShowConfirmation``
    ///     and defers the hosted approve ``WKWebView`` until ``presentPendingBuiltInPayPalForForwardPayment(onCompletion:)`` runs.
    ///   - completion: Called with the payment result
    func processPayment(
        method: PaymentMethodType,
        item: PaymentItem,
        context: PaymentContext,
        cartItemId: String,
        from viewController: UIViewController,
        builtInPayPalDevicePaySession: BuiltInTwoStepDevicePaySession? = nil,
        builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession? = nil,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        if method == .paypal {
            processBuiltInPayPalPayment(
                item: item,
                context: context,
                cartItemId: cartItemId,
                from: viewController,
                devicePaySession: builtInPayPalDevicePaySession,
                completion: completion
            )
            return
        }

        if method == .card, let cardSession = builtInCardDevicePaySession {
            processBuiltInCardPayment(
                item: item,
                context: context,
                cartItemId: cartItemId,
                devicePaySession: cardSession,
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
    /// ``PaymentContext/returnURL`` and ``PaymentContext/cancelURL`` through to the API body when present,
    /// and `payment_method` / `payment_provider` as `PAYPAL` for the cart API.
    /// For device pay from a placement, ``Rokt/setBuiltInPayPalRedirectURLScheme(_:)`` supplies those URLs on ``PaymentContext``.
    /// After cart prepare, calls ``RoktUX/devicePayShowConfirmation`` (via ``BuiltInTwoStepDevicePaySession``) and defers the hosted
    /// PayPal approve step until ``presentPendingBuiltInPayPalForForwardPayment(onCompletion:)`` runs from the forward-payment handler.
    private func processBuiltInPayPalPayment(
        item: PaymentItem,
        context: PaymentContext,
        cartItemId: String,
        from viewController: UIViewController,
        devicePaySession: BuiltInTwoStepDevicePaySession?,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        let contactAddress = Self.contactAddressForInitializePurchase(context: context)
        preparePaymentForItem(
            item: item,
            cartItemId: cartItemId,
            contactAddress: contactAddress,
            returnURL: context.returnURL,
            cancelURL: context.cancelURL,
            paymentMethod: Self.builtInPayPalInitializePurchaseMethod,
            paymentProvider: Self.builtInPayPalInitializePurchaseProvider
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

                guard let devicePaySession else {
                    DispatchQueue.main.async {
                        completion(.failed(error: Self.builtInPayPalMissingDeferredSessionMessage))
                    }
                    return
                }
                guard let returnURL = context.returnURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !returnURL.isEmpty,
                      URL(string: returnURL) != nil
                else {
                    Self.clearPendingBuiltInTwoStepStateUnderLock()
                    DispatchQueue.main.async {
                        completion(.failed(error: Self.payPalReturnURLMissingMessage))
                    }
                    return
                }
                let sanitizedCancelURL = Self.nonEmptyTrimmed(context.cancelURL)
                let catalogRuntimeData = Self.catalogRuntimeDataForDevicePayConfirmation(item: item, preparation: preparation)
                devicePaySession.showConfirmation(devicePaySession.layoutId, devicePaySession.catalogItemId, catalogRuntimeData)

                let pending = PendingBuiltInPayPalWebCheckout(
                    owner: self,
                    approvalURL: approvalURL,
                    returnURLString: returnURL,
                    cancelURLString: sanitizedCancelURL,
                    presentingViewController: viewController,
                    completion: completion
                )
                Self.pendingBuiltInTwoStepLock.lock()
                Self.pendingBuiltInTwoStepCheckout = .paypal(pending)
                Self.pendingBuiltInTwoStepLock.unlock()
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failed(error: error.localizedDescription))
                }
            }
        }
    }

    /// PayPal-only forward-payment entry point: open the cached approval URL
    /// fire `onCompletion` once the coordinator resolves via the in-webview redirect
    /// or the deep-link `handleURLCallback` path.
    ///
    /// backend webhook finalizes the purchase from the PayPal redirect; the SDK only needs
    /// to surface success/cancel/failure to the UXHelper.
    ///
    /// - Parameter onCompletion: called on the main queue with the coordinator outcome.
    /// - Returns: `true` when a pending PayPal checkout existed and was presented; `false`
    ///   when the caller should fall through to the non-PayPal `/v1/cart/purchase` flow.
    @discardableResult
    func presentPendingBuiltInPayPalForForwardPayment(
        onCompletion: @escaping (PaymentSheetResult) -> Void
    ) -> Bool {
        Self.pendingBuiltInTwoStepLock.lock()
        // Only consume PayPal entries; leave a card entry intact for ``popPendingBuiltInCardCompletion``.
        guard case let .paypal(snapshot) = Self.pendingBuiltInTwoStepCheckout,
              snapshot.owner === self
        else {
            Self.pendingBuiltInTwoStepLock.unlock()
            return false
        }
        Self.pendingBuiltInTwoStepCheckout = nil
        Self.pendingBuiltInTwoStepLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                let result = PaymentSheetResult.failed(error: Self.payPalReturnURLMissingMessage)
                snapshot.completion(result)
                onCompletion(result)
                return
            }
            // Fall back to the current top view controller when the originally captured weak
            // reference has been deallocated (e.g. host app dismissed and re-presented Rokt).
            guard let viewController = snapshot.presentingViewController ?? UIApplication.topViewController() else {
                let result = PaymentSheetResult.failed(
                    error: "No view controller available for PayPal checkout."
                )
                snapshot.completion(result)
                onCompletion(result)
                return
            }
            let coordinator = PayPalCheckoutCoordinator(
                returnURLString: snapshot.returnURLString,
                cancelURLString: snapshot.cancelURLString,
                completion: { [weak self] result in
                    self?.activePayPalCheckout = nil
                    snapshot.completion(result)
                    onCompletion(result)
                }
            )
            self.activePayPalCheckout = coordinator
            self.payPalApprovalPresenter.presentPayPalApproval(
                approvalURL: snapshot.approvalURL,
                from: viewController,
                checkoutCoordinator: coordinator
            )
        }
        return true
    }

    /// Called when forward-payment fails or cannot run, so a deferred two-step session does not leak.
    /// Fires the cached completion with a provider-appropriate cancellation message.
    func cancelPendingBuiltInTwoStepIfNeeded() {
        Self.pendingBuiltInTwoStepLock.lock()
        let snapshot = Self.pendingBuiltInTwoStepCheckout
        Self.pendingBuiltInTwoStepCheckout = nil
        Self.pendingBuiltInTwoStepLock.unlock()
        guard let snapshot else { return }
        DispatchQueue.main.async {
            switch snapshot {
            case .paypal(let pending):
                pending.completion(.failed(error: "PayPal checkout was canceled."))
            case .card(let pending):
                pending.completion(.failed(error: "Card checkout was canceled."))
            }
        }
    }

    // MARK: - Built-in Card forwarding (no PaymentExtension)

    /// Entry point for Card device-pay (Step-1 of the two-step Card forward-payment flow).
    ///
    /// Runs the same cart ``initializePurchase`` preparation as PayPal but without `paymentMethod` /
    /// `paymentProvider` overrides or return/cancel URLs (no hosted approval step). After cart prepare,
    /// triggers ``RoktUX/devicePayShowConfirmation`` so the layout transitions to the Step-2 confirm
    /// button, and caches `completion` so it can fire alongside ``forwardPaymentFinalized`` once
    /// ``handleForwardPayment`` posts to `/v1/cart/purchase`.
    private func processBuiltInCardPayment(
        item: PaymentItem,
        context: PaymentContext,
        cartItemId: String,
        devicePaySession: BuiltInTwoStepDevicePaySession,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        let contactAddress = Self.contactAddressForInitializePurchase(context: context)
        preparePaymentForItem(
            item: item,
            cartItemId: cartItemId,
            contactAddress: contactAddress,
            returnURL: nil,
            cancelURL: nil
        ) { result in
            switch result {
            case .success(let preparation):
                let catalogRuntimeData = Self.catalogRuntimeDataForDevicePayConfirmation(item: item, preparation: preparation)
                devicePaySession.showConfirmation(devicePaySession.layoutId, devicePaySession.catalogItemId, catalogRuntimeData)

                let pending = PendingBuiltInCardCheckout(owner: self, completion: completion)
                Self.pendingBuiltInTwoStepLock.lock()
                Self.pendingBuiltInTwoStepCheckout = .card(pending)
                Self.pendingBuiltInTwoStepLock.unlock()
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failed(error: error.localizedDescription))
                }
            }
        }
    }

    /// Card-only forward-payment hook: pop the cached Step-1 completion so the caller can
    /// fire it after `/v1/cart/purchase` resolves.
    ///
    /// Card has no orchestrator-driven Step-2 (no WebView). ``handleForwardPayment`` runs the
    /// standard `/v1/cart/purchase` path; this method just hands back the deferred completion
    /// so device-pay finalization can chain off the same response.
    ///
    /// - Returns: the cached completion when the pending checkout was a card flow owned by
    ///   this orchestrator; `nil` otherwise (so PayPal entries are left intact).
    func popPendingBuiltInCardCompletion() -> ((PaymentSheetResult) -> Void)? {
        Self.pendingBuiltInTwoStepLock.lock()
        defer { Self.pendingBuiltInTwoStepLock.unlock() }
        guard case let .card(snapshot) = Self.pendingBuiltInTwoStepCheckout,
              snapshot.owner === self
        else {
            return nil
        }
        Self.pendingBuiltInTwoStepCheckout = nil
        return snapshot.completion
    }

    // Clears static deferred state without invoking a completion (unit tests).
    // periphery:ignore
    static func resetBuiltInTwoStepDeferredStateForTesting() {
        pendingBuiltInTwoStepLock.lock()
        pendingBuiltInTwoStepCheckout = nil
        pendingBuiltInTwoStepLock.unlock()
    }

    private static func clearPendingBuiltInTwoStepStateUnderLock() {
        pendingBuiltInTwoStepLock.lock()
        pendingBuiltInTwoStepCheckout = nil
        pendingBuiltInTwoStepLock.unlock()
    }

    private static func catalogRuntimeDataForDevicePayConfirmation(
        item: PaymentItem,
        preparation: PaymentPreparation
    ) -> [String: String] {
        let code = item.currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "USD" : item.currency
        // Mirror the upsell item ``runInitializePurchase`` builds so subtotal reflects
        // ``UpsellItem/totalPrice`` (single quantity-1 line item from the request) rather
        // than `totalAmount − tax − shipping` arithmetic that drifts if backend tweaks rounding.
        let upsell = UpsellItem(
            cartItemId: "",
            catalogItemId: item.id,
            quantity: 1,
            unitPrice: item.amount.decimalValue,
            totalPrice: item.amount.decimalValue,
            currency: code
        )
        return BreakdownFormatter.format(
            upsellItems: [upsell],
            shippingCost: preparation.shippingCost.decimalValue,
            tax: preparation.tax.decimalValue,
            totalAmount: preparation.totalAmount.decimalValue,
            currency: code
        )
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
        paymentMethod: String? = nil,
        paymentProvider: String? = nil,
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
            paymentMethod: paymentMethod,
            paymentProvider: paymentProvider,
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

                if let paypalData = response.paypalData {
                    RoktLogger.shared.verbose(
                        "\(Self.devicePayErrorCode) initialize-purchase PayPal order id length=\(paypalData.orderId.count)"
                    )
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
