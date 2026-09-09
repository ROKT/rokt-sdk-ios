import Foundation
import UIKit
import RoktContracts

/// Layout context and confirmation hook for built-in **two-step device pay** flows (PayPal, Card).
///
/// Used to drive ``RoktUX/devicePayShowConfirmation`` from the orchestrator after Step-1
/// (`initialize-purchase`) resolves, so the layout can transition to the Step-2 confirm button.
struct BuiltInTwoStepDevicePaySession {
    let executeId: String
    let layoutId: String
    let catalogItemId: String
    let showConfirmation: (_ layoutId: String, _ catalogItemId: String, _ catalogRuntimeData: [String: String]) -> Void

    /// Key under which this session's Step-1 result waits for the same item's Step-2 confirm.
    func checkoutKey(cartItemId: String) -> BuiltInTwoStepCheckoutKey {
        BuiltInTwoStepCheckoutKey(
            executeId: executeId,
            layoutId: layoutId,
            catalogItemId: catalogItemId,
            cartItemId: cartItemId
        )
    }
}

/// Identifies the item and placement a built-in two-step Step-1 was started for. Deferred Step-1 state is
/// kept under this key so only the same item's Step-2 confirm can resume it.
struct BuiltInTwoStepCheckoutKey: Hashable {
    let executeId: String
    let layoutId: String
    let catalogItemId: String
    let cartItemId: String
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
    /// Cart prepare returned a PayPal approval URL that is not an `http`/`https` URL with a host.
    static let payPalApprovalURLInvalidMessage =
        "PayPal approval URL must be an http or https URL with a host; cannot start checkout."
    /// Cart prepare returned PayPal data without an order id, so a return link could not be tied to this checkout.
    static let payPalOrderIdMissingMessage =
        "PayPal order id was not returned; cannot start checkout."
    /// A return or cancel link for the active checkout did not name the order it started; the checkout stays pending.
    static let payPalReturnLinkOrderMismatchMessage =
        "PayPal return link did not reference the pending order; ignored."
    /// Built-in PayPal uses ``PaymentContext/returnURL`` to detect completion when PayPal redirects after approval.
    static let payPalReturnURLMissingMessage =
        "PaymentContext.returnURL is required for PayPal checkout."
    /// Cart `initialize-purchase` body `paymentMethodType` wire value. PascalCase tokens that
    /// match both the cart-api `PaymentMethodType` member names and the values DCUI returns in
    /// `paymentProvider` — so iOS sends the method back in the same vocabulary it receives.
    /// Accepted by the cart-api `InitializePurchaseApiRequest` contract (Newtonsoft matches enum
    /// member names case-insensitively). Distinct from the short `TransactionData.type` tokens
    /// (`"CARD"`, `"APPLE_PAY"`, …) — `"APPLE_PAY"` would not deserialize — and from
    /// ``PaymentMethodType/wireValue`` (extension matching; uses `"afterpay_clearpay"`).
    static func cartPaymentMethodTypeWireValue(for method: PaymentMethodType) -> String {
        switch method {
        case .applePay: return "ApplePay"
        case .card: return "Card"
        case .afterpay: return "Afterpay"
        case .paypal: return "Paypal"
        }
    }

    /// Cart `initialize-purchase` body `paymentProvider` wire value for built-in flows.
    /// PascalCase pass-through of the `DcuiSchema.PaymentProvider` enum — matches the web
    /// SDK payload (`paymentProvider: PaymentProvider`) on `INITIATE_DEVICE_PAY_EVENT`.
    /// Used only for built-in flows that hardcode their own provider (PayPal, Card);
    /// extension-routed flows forward the caller-supplied PascalCase value verbatim.
    static func cartPaymentProviderWireValue(for method: PaymentMethodType) -> String {
        switch method {
        case .applePay: return "ApplePay"
        case .card: return "Card"
        case .afterpay: return "Afterpay"
        case .paypal: return "PayPal"
        }
    }

    private static let pendingBuiltInTwoStepLock = NSLock()

    /// Cart prepare result plus the PayPal order id the response carried (nil when absent or empty).
    /// `PaymentPreparation` is a contracts type, so the order id rides beside it rather than inside it.
    private struct PreparedPurchase {
        let preparation: PaymentPreparation
        let payPalOrderId: String?
    }

    /// PayPal Step-1 cache: WebView context + deferred Step-1 completion fired on Step-2 resolve.
    private struct PendingBuiltInPayPalWebCheckout {
        weak var owner: PaymentOrchestrator?
        let approvalURL: URL
        /// Order id from cart prepare; the return link must carry it before the checkout completes.
        let orderId: String
        let returnURLString: String
        let cancelURLString: String?
        weak var presentingViewController: UIViewController?
        let completion: (PaymentSheetResult) -> Void
    }

    /// Card Step-1 cache: just the deferred completion. Forward-payment cart purchase (POST `/v1/cart/purchase`)
    /// runs in ``ForwardPaymentCartPurchaseCoordinator`` via ``RoktInternalImplementation.handleForwardPayment``;
    /// the orchestrator only holds the completion so it can fire alongside ``forwardPaymentFinalized``.
    private struct PendingBuiltInCardCheckout {
        weak var owner: PaymentOrchestrator?
        let completion: (PaymentSheetResult) -> Void
    }

    private enum PendingBuiltInTwoStepCheckout {
        case paypal(PendingBuiltInPayPalWebCheckout)
        /// Card confirm is shown; buyer has not yet started `/v1/cart/purchase` for this session.
        case card(PendingBuiltInCardCheckout)
        /// Forward-payment cart purchase POST (built-in two-step) is in flight; same snapshot as ``card`` until terminal or retryable restore.
        case cardInFlight(PendingBuiltInCardCheckout)
    }

    /// Deferred Step-1 state per item and placement. Step-2 consumes only the entry under its own event's key,
    /// so a confirm for one item never resumes another item's checkout; entries for a closed placement or a
    /// cleared session are discarded.
    private static var pendingBuiltInTwoStepCheckouts: [BuiltInTwoStepCheckoutKey: PendingBuiltInTwoStepCheckout] = [:]

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

    /// All available payment methods across registered extensions, plus enabled built-in payment forwarding methods.
    func availablePaymentMethods(isBuiltInPayPalAvailable: Bool = true) -> [PaymentMethodType] {
        var methods = Set(
            registeredExtensions.flatMap { $0.supportedMethods }.compactMap { PaymentMethodType(wireValue: $0) }
        )
        methods.insert(.card)
        if isBuiltInPayPalAvailable {
            methods.insert(.paypal)
        }
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
    ///   - method: The payment method to use (e.g. `.applePay`). Forwarded to the cart
    ///     `initialize-purchase` body as a `paymentMethodType` value (e.g. `"ApplePay"`)
    ///     via ``cartPaymentMethodTypeWireValue(for:)``.
    ///   - paymentProvider: PascalCase cart wire value for the upstream processor (e.g. `"Stripe"`,
    ///     `"Afterpay"`). Forwarded as `paymentProvider` on the cart `initialize-purchase` body
    ///     for extension-routed flows. Ignored for built-in PayPal and built-in card forwarding,
    ///     which hardcode their own `paymentMethodType` / `paymentProvider`
    ///     (`"Paypal"` / `"PayPal"`, `"Card"` / `"Card"`).
    ///   - item: The item being purchased (from RoktContracts)
    ///   - cartItemId: The backend cart item ID (format `"v1:uuid:canal"`)
    ///   - viewController: The view controller to present the payment sheet from
    ///   - builtInPayPalDevicePaySession: For built-in PayPal **device pay** only; drives ``RoktUX/devicePayShowConfirmation``
    ///     and defers the hosted approve ``SFSafariViewController`` until ``presentPendingBuiltInPayPalForForwardPayment(onCompletion:)`` runs.
    ///   - completion: Called with the payment result
    func processPayment(
        method: PaymentMethodType,
        paymentProvider: String? = nil,
        item: PaymentItem,
        context: PaymentContext,
        cartItemId: String,
        from viewController: UIViewController,
        builtInPayPalDevicePaySession: BuiltInTwoStepDevicePaySession? = nil,
        builtInCardDevicePaySession: BuiltInTwoStepDevicePaySession? = nil,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        if method == .paypal {
            Self.warnIfCallerSuppliedProviderIgnored(
                method: method,
                callerProvider: paymentProvider,
                hardcodedProvider: Self.cartPaymentProviderWireValue(for: .paypal)
            )
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
            Self.warnIfCallerSuppliedProviderIgnored(
                method: method,
                callerProvider: paymentProvider,
                hardcodedProvider: Self.cartPaymentProviderWireValue(for: .card)
            )
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

        var lastPreparePaymentFailureMessage: String?

        // The preparePayment callback bridges the completion-handler pattern
        // to the SDK's backend API call (initializePurchase)
        let preparePayment: (ContactAddress, @escaping (PaymentPreparation?, Error?) -> Void)
            -> Void = { contactAddress, prepareCompletion in
            self.preparePaymentForItem(
                item: item,
                cartItemId: cartItemId,
                contactAddress: contactAddress,
                returnURL: nil,
                cancelURL: nil,
                // `cartPaymentMethodTypeWireValue` is total and guaranteed non-empty; only the
                // caller-supplied provider needs whitespace/empty normalization.
                paymentMethodType: Self.cartPaymentMethodTypeWireValue(for: method),
                paymentProvider: Self.nonEmptyTrimmed(paymentProvider)
            ) { result in
                switch result {
                case .success(let prepared):
                    lastPreparePaymentFailureMessage = nil
                    prepareCompletion(prepared.preparation, nil)
                case .failure(let error):
                    lastPreparePaymentFailureMessage = error.localizedDescription
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
            completion: { [weak self] result in
                if result.outcome == .failed,
                   result.errorMessage != lastPreparePaymentFailureMessage {
                    self?.sendPaymentFailureDiagnostics(
                        method: method,
                        item: item,
                        cartItemId: cartItemId,
                        result: result
                    )
                }
                completion(result)
            }
        )
    }

    // MARK: - Built-in PayPal (no PaymentExtension)

    /// Entry point for PayPal device pay. Does not consult ``registeredExtensions``.
    ///
    /// Runs the same cart ``initializePurchase`` preparation as extension-based flows, passing
    /// ``PaymentContext/returnURL`` and ``PaymentContext/cancelURL`` through to the API body when present,
    /// and `paymentMethodType` / `paymentProvider` as `Paypal` / `PayPal` for the cart API.
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
            paymentMethodType: Self.cartPaymentMethodTypeWireValue(for: .paypal),
            paymentProvider: Self.cartPaymentProviderWireValue(for: .paypal)
        ) { result in
            switch result {
            case .success(let prepared):
                let preparation = prepared.preparation
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
                // Only the scheme and whether a host is present are logged; the URL itself carries the order token.
                guard approvalURL.isWebURLWithHost() else {
                    self.apiHelper.sendDiagnostics(
                        message: Self.devicePayErrorCode,
                        callStack: Self.payPalApprovalURLInvalidMessage,
                        severity: .warning,
                        additionalInfo: [
                            "scheme": approvalURL.scheme ?? "",
                            "hostPresent": !(approvalURL.host ?? "").isEmpty
                        ]
                    )
                    DispatchQueue.main.async {
                        completion(.failed(error: Self.payPalApprovalURLInvalidMessage))
                    }
                    return
                }
                guard let orderId = prepared.payPalOrderId else {
                    self.apiHelper.sendDiagnostics(
                        message: Self.devicePayErrorCode,
                        callStack: Self.payPalOrderIdMissingMessage,
                        severity: .warning
                    )
                    DispatchQueue.main.async {
                        completion(.failed(error: Self.payPalOrderIdMissingMessage))
                    }
                    return
                }

                guard let devicePaySession else {
                    DispatchQueue.main.async {
                        completion(.failed(error: Self.builtInPayPalMissingDeferredSessionMessage))
                    }
                    return
                }
                let key = devicePaySession.checkoutKey(cartItemId: cartItemId)
                guard let returnURL = context.returnURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !returnURL.isEmpty,
                      URL(string: returnURL) != nil
                else {
                    Self.removePendingBuiltInTwoStep(for: key)
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
                    orderId: orderId,
                    returnURLString: returnURL,
                    cancelURLString: sanitizedCancelURL,
                    presentingViewController: viewController,
                    completion: completion
                )
                Self.pendingBuiltInTwoStepLock.lock()
                Self.pendingBuiltInTwoStepCheckouts[key] = .paypal(pending)
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
    /// If the buyer cancels the hosted step (Safari dismissed or cancel deep link), the SDK
    /// does **not** invoke `onCompletion` or the deferred Step-1 `completion`; it re-queues the
    /// same pending checkout so the confirmation UI can stay up and ``presentPendingBuiltInPayPalForForwardPayment``
    /// can run again.
    ///
    /// - Parameters:
    ///   - key: item and placement of the Step-2 confirm; only that item's pending PayPal checkout is consumed.
    ///   - onCompletion: called on the main queue with the coordinator outcome.
    /// - Returns: `true` when a pending PayPal checkout existed for `key` and was presented; `false`
    ///   when the caller should fall through to the non-PayPal `/v1/cart/purchase` flow.
    @discardableResult
    func presentPendingBuiltInPayPalForForwardPayment(
        for key: BuiltInTwoStepCheckoutKey,
        onCompletion: @escaping (PaymentSheetResult) -> Void
    ) -> Bool {
        Self.pendingBuiltInTwoStepLock.lock()
        // Only consume PayPal entries; leave built-in card entries (``card`` / ``cardInFlight``) intact.
        guard case let .paypal(snapshot)? = Self.pendingBuiltInTwoStepCheckouts[key],
              snapshot.owner === self
        else {
            Self.pendingBuiltInTwoStepLock.unlock()
            return false
        }
        Self.pendingBuiltInTwoStepCheckouts.removeValue(forKey: key)
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
                expectedOrderId: snapshot.orderId,
                completion: { [weak self] result in
                    self?.activePayPalCheckout = nil
                    if result.outcome == .canceled {
                        if let self {
                            Self.requeuePendingBuiltInPayPalAfterForwardPaymentCancel(
                                key: key,
                                snapshot: snapshot,
                                owner: self
                            )
                        } else {
                            snapshot.completion(result)
                            onCompletion(result)
                        }
                        return
                    }
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

    private static func requeuePendingBuiltInPayPalAfterForwardPaymentCancel(
        key: BuiltInTwoStepCheckoutKey,
        snapshot: PendingBuiltInPayPalWebCheckout,
        owner: PaymentOrchestrator
    ) {
        let restored = PendingBuiltInPayPalWebCheckout(
            owner: owner,
            approvalURL: snapshot.approvalURL,
            orderId: snapshot.orderId,
            returnURLString: snapshot.returnURLString,
            cancelURLString: snapshot.cancelURLString,
            presentingViewController: snapshot.presentingViewController,
            completion: snapshot.completion
        )
        pendingBuiltInTwoStepLock.lock()
        pendingBuiltInTwoStepCheckouts[key] = .paypal(restored)
        pendingBuiltInTwoStepLock.unlock()
    }

    /// Called when forward-payment for `key` fails or cannot run, so its deferred two-step session does not leak.
    /// Fires the cached completion with a provider-appropriate cancellation message.
    func cancelPendingBuiltInTwoStep(for key: BuiltInTwoStepCheckoutKey) {
        Self.pendingBuiltInTwoStepLock.lock()
        let snapshot = Self.pendingBuiltInTwoStepCheckouts.removeValue(forKey: key)
        Self.pendingBuiltInTwoStepLock.unlock()
        guard let snapshot else { return }
        DispatchQueue.main.async {
            switch snapshot {
            case .paypal(let pending):
                pending.completion(.failed(error: "PayPal checkout was canceled."))
            case .card(let pending), .cardInFlight(let pending):
                pending.completion(.failed(error: "Card checkout was canceled."))
            }
        }
    }

    // MARK: - Built-in Card forwarding (no PaymentExtension)

    /// Entry point for Card device-pay (Step-1 of the two-step card forwarding flow).
    ///
    /// Runs the same cart ``initializePurchase`` preparation as PayPal but without return/cancel URLs
    /// (no hosted approval step). Passes `paymentMethodType` / `paymentProvider` as `Card` / `Card`.
    /// After cart prepare, triggers ``RoktUX/devicePayShowConfirmation`` so the layout transitions
    /// to the Step-2 confirm button, and caches `completion` so it can fire alongside
    /// ``forwardPaymentFinalized`` once card forwarding completes in ``handleForwardPayment``.
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
            cancelURL: nil,
            paymentMethodType: Self.cartPaymentMethodTypeWireValue(for: .card),
            paymentProvider: Self.cartPaymentProviderWireValue(for: .card)
        ) { result in
            switch result {
            case .success(let prepared):
                let catalogRuntimeData = Self.catalogRuntimeDataForDevicePayConfirmation(
                    item: item,
                    preparation: prepared.preparation
                )
                devicePaySession.showConfirmation(devicePaySession.layoutId, devicePaySession.catalogItemId, catalogRuntimeData)

                let pending = PendingBuiltInCardCheckout(owner: self, completion: completion)
                Self.pendingBuiltInTwoStepLock.lock()
                Self.pendingBuiltInTwoStepCheckouts[devicePaySession.checkoutKey(cartItemId: cartItemId)] = .card(pending)
                Self.pendingBuiltInTwoStepLock.unlock()
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failed(error: error.localizedDescription))
                }
            }
        }
    }

    /// Begins a built-in card forwarding cart purchase attempt: moves ``card`` → ``cardInFlight`` and returns
    /// the Step-1 completion to invoke only after a **terminal** `/v1/cart/purchase` outcome.
    ///
    /// - Returns: the deferred Step-1 completion when state for `key` was ``card`` for this orchestrator;
    ///   `nil` if that item has no card session, PayPal is cached for it instead, or its card attempt is
    ///   already ``cardInFlight`` for this owner (avoid duplicate POSTs).
    func beginBuiltInCardForwardPaymentIfReady(for key: BuiltInTwoStepCheckoutKey) -> ((PaymentSheetResult) -> Void)? {
        Self.pendingBuiltInTwoStepLock.lock()
        defer { Self.pendingBuiltInTwoStepLock.unlock() }
        guard case let .card(snapshot)? = Self.pendingBuiltInTwoStepCheckouts[key],
              snapshot.owner === self
        else {
            return nil
        }
        Self.pendingBuiltInTwoStepCheckouts[key] = .cardInFlight(snapshot)
        return snapshot.completion
    }

    /// `true` when built-in card forwarding has begun (``cardInFlight``) for any item of this orchestrator;
    /// one `/v1/cart/purchase` at a time.
    func isBuiltInCardForwardPaymentInFlight() -> Bool {
        Self.pendingBuiltInTwoStepLock.lock()
        defer { Self.pendingBuiltInTwoStepLock.unlock() }
        return Self.pendingBuiltInTwoStepCheckouts.values.contains { entry in
            guard case let .cardInFlight(snapshot) = entry else { return false }
            return snapshot.owner === self
        }
    }

    /// After a retryable card forwarding `/v1/cart/purchase` failure, move `key` from ``cardInFlight`` back to
    /// ``card`` so the buyer can tap confirm again without re-running Step-1 ``initializePurchase``.
    func restoreBuiltInCardForwardPaymentAfterRetryableFailure(for key: BuiltInTwoStepCheckoutKey) {
        Self.pendingBuiltInTwoStepLock.lock()
        defer { Self.pendingBuiltInTwoStepLock.unlock() }
        guard case let .cardInFlight(snapshot)? = Self.pendingBuiltInTwoStepCheckouts[key],
              snapshot.owner === self
        else {
            return
        }
        Self.pendingBuiltInTwoStepCheckouts[key] = .card(snapshot)
    }

    /// Ends a built-in card forwarding attempt for `key`: clears ``cardInFlight`` and delivers ``result`` to the
    /// Step-1 ``processPayment`` completion on the main queue.
    func finishBuiltInCardForwardPaymentAttempt(for key: BuiltInTwoStepCheckoutKey, result: PaymentSheetResult) {
        var completion: ((PaymentSheetResult) -> Void)?
        Self.pendingBuiltInTwoStepLock.lock()
        if case let .cardInFlight(snapshot)? = Self.pendingBuiltInTwoStepCheckouts[key],
           snapshot.owner === self {
            completion = snapshot.completion
            Self.pendingBuiltInTwoStepCheckouts.removeValue(forKey: key)
        }
        Self.pendingBuiltInTwoStepLock.unlock()
        guard let completion else { return }
        DispatchQueue.main.async {
            completion(result)
        }
    }

    // MARK: - Lifecycle fences

    /// Drops deferred Step-1 state for every item of `executeId` without invoking completions: the placement
    /// is gone, so no confirm button can resume them and no failure event is owed for them.
    func discardPendingBuiltInTwoStep(forExecuteId executeId: String) {
        Self.pendingBuiltInTwoStepLock.lock()
        Self.pendingBuiltInTwoStepCheckouts = Self.pendingBuiltInTwoStepCheckouts.filter { $0.key.executeId != executeId }
        Self.pendingBuiltInTwoStepLock.unlock()
    }

    /// Drops all deferred Step-1 state without invoking completions; called at a session boundary so nothing
    /// started under one session can be resumed under the next.
    func discardAllPendingBuiltInTwoStep() {
        Self.pendingBuiltInTwoStepLock.lock()
        Self.pendingBuiltInTwoStepCheckouts.removeAll()
        Self.pendingBuiltInTwoStepLock.unlock()
    }

    // Clears static deferred state without invoking a completion (unit tests).
    // periphery:ignore
    static func resetBuiltInTwoStepDeferredStateForTesting() {
        pendingBuiltInTwoStepLock.lock()
        pendingBuiltInTwoStepCheckouts.removeAll()
        pendingBuiltInTwoStepLock.unlock()
    }

    // Unit test hook: installs deferred built-in card Step-1 for `key` without calling `initializePurchase`.
    // Use the same `PaymentOrchestrator` instance as production when exercising `handleForwardPayment`
    // together with `beginBuiltInCardForwardPaymentIfReady`.
    // periphery:ignore
    internal func unitTest_seedDeferredBuiltInCardForwardPayment(
        for key: BuiltInTwoStepCheckoutKey,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        let pending = PendingBuiltInCardCheckout(owner: self, completion: completion)
        Self.pendingBuiltInTwoStepLock.lock()
        Self.pendingBuiltInTwoStepCheckouts[key] = .card(pending)
        Self.pendingBuiltInTwoStepLock.unlock()
    }

    // Unit test hook: installs deferred built-in PayPal Step-1 for `key` without calling `initializePurchase`.
    // periphery:ignore
    internal func unitTest_seedDeferredBuiltInPayPalForwardPayment(
        for key: BuiltInTwoStepCheckoutKey,
        approvalURL: URL,
        returnURLString: String,
        orderId: String,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        let pending = PendingBuiltInPayPalWebCheckout(
            owner: self,
            approvalURL: approvalURL,
            orderId: orderId,
            returnURLString: returnURLString,
            cancelURLString: nil,
            presentingViewController: nil,
            completion: completion
        )
        Self.pendingBuiltInTwoStepLock.lock()
        Self.pendingBuiltInTwoStepCheckouts[key] = .paypal(pending)
        Self.pendingBuiltInTwoStepLock.unlock()
    }

    // Unit test hook: whether deferred Step-1 state exists for `key` (either provider, any phase).
    // periphery:ignore
    internal func unitTest_hasPendingBuiltInTwoStep(for key: BuiltInTwoStepCheckoutKey) -> Bool {
        Self.pendingBuiltInTwoStepLock.lock()
        defer { Self.pendingBuiltInTwoStepLock.unlock() }
        return Self.pendingBuiltInTwoStepCheckouts[key] != nil
    }

    private static func removePendingBuiltInTwoStep(for key: BuiltInTwoStepCheckoutKey) {
        pendingBuiltInTwoStepLock.lock()
        pendingBuiltInTwoStepCheckouts.removeValue(forKey: key)
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

    /// Logs when a built-in flow ignored a caller-supplied `paymentProvider` that
    /// disagrees with the hardcoded override. Helps the next person catch a wiring
    /// bug (e.g. plumbing `"Stripe"` into a built-in PayPal flow) without changing
    /// the cart payload semantics.
    private static func warnIfCallerSuppliedProviderIgnored(
        method: PaymentMethodType,
        callerProvider: String?,
        hardcodedProvider: String
    ) {
        guard let provided = nonEmptyTrimmed(callerProvider),
              provided != hardcodedProvider
        else { return }
        RoktLogger.shared.warning(
            "Built-in \(method.wireValue) flow ignoring caller-supplied " +
                "paymentProvider=\(provided); using \(hardcodedProvider)."
        )
    }

    private func sendPaymentFailureDiagnostics(
        method: PaymentMethodType,
        item: PaymentItem,
        cartItemId: String,
        result: PaymentSheetResult
    ) {
        let errorMessage = result.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let callStack = errorMessage?.isEmpty == false
            ? errorMessage ?? ""
            : "Payment extension failed without an error message"
        apiHelper.sendDiagnostics(
            message: Self.devicePayErrorCode,
            callStack: callStack,
            severity: .warning,
            additionalInfo: [
                "paymentMethod": method.wireValue,
                "cartItemId": cartItemId,
                "catalogItemId": item.id
            ]
        )
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
    ///
    /// A link that matches the return or cancel URL but does not name the pending order is still claimed
    /// (never offered to payment extensions) and leaves the checkout pending for the genuine redirect.
    private func handleBuiltInPayPalURLIfNeeded(_ url: URL) -> Bool {
        guard let checkout = activePayPalCheckout else { return false }
        let outcome = checkout.handleDeepLinkReturn(url)
        switch outcome {
        case .notOurs:
            return false
        case .alreadyDone, .completedReturn, .completedCancel:
            return true
        case .rejectedMissingToken, .rejectedTokenMismatch:
            apiHelper.sendDiagnostics(
                message: Self.devicePayErrorCode,
                callStack: Self.payPalReturnLinkOrderMismatchMessage,
                severity: .warning,
                additionalInfo: ["tokenPresent": outcome == .rejectedTokenMismatch]
            )
            return true
        }
    }

    // MARK: - Private

    private func preparePaymentForItem(
        item: PaymentItem,
        cartItemId: String,
        contactAddress: ContactAddress,
        returnURL: String? = nil,
        cancelURL: String? = nil,
        paymentMethodType: String? = nil,
        paymentProvider: String? = nil,
        completion: @escaping (Result<PreparedPurchase, Error>) -> Void
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
            paymentMethodType: paymentMethodType,
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
                completion(.success(PreparedPurchase(
                    preparation: preparation,
                    payPalOrderId: Self.nonEmptyTrimmed(response.paypalData?.orderId)
                )))
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
