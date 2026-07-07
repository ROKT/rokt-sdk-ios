import Foundation
import RoktContracts
internal import RoktUXHelper

/// Runs forward-payment cart purchase (`/v1/cart/purchase`): built-in two-step card (device pay),
/// or extension-routed card (e.g. Stripe) when there is no deferred built-in session. Applies the same
/// retry heuristics for both so retryable failures can skip finalization until a terminal outcome.
final class ForwardPaymentCartPurchaseCoordinator {
    private let paymentOrchestrator: PaymentOrchestrator
    private let unknownFailureReason: String
    private let missingPriceFailureReason: String
    private let resolveCartPurchaseFinalization: (PurchaseResponse) -> (success: Bool, failureReason: String?)
    private let resolveTransportFailureFinalization: (String) -> (success: Bool, failureReason: String?)
    private let emitRoktEvent: (String, RoktEvent?) -> Void
    private let finalizeForwardPayment: (String, String, String, Bool, String?) -> Void

    init(
        paymentOrchestrator: PaymentOrchestrator,
        unknownFailureReason: String,
        missingPriceFailureReason: String,
        resolveCartPurchaseFinalization: @escaping (PurchaseResponse) -> (success: Bool, failureReason: String?),
        resolveTransportFailureFinalization: @escaping (String) -> (success: Bool, failureReason: String?),
        emitRoktEvent: @escaping (String, RoktEvent?) -> Void,
        finalizeForwardPayment: @escaping (String, String, String, Bool, String?) -> Void
    ) {
        self.paymentOrchestrator = paymentOrchestrator
        self.unknownFailureReason = unknownFailureReason
        self.missingPriceFailureReason = missingPriceFailureReason
        self.resolveCartPurchaseFinalization = resolveCartPurchaseFinalization
        self.resolveTransportFailureFinalization = resolveTransportFailureFinalization
        self.emitRoktEvent = emitRoktEvent
        self.finalizeForwardPayment = finalizeForwardPayment
    }

    /// Runs the forward-payment cart purchase (`/v1/cart/purchase`): in-flight guard (built-in two-step path),
    /// request build, API call, and retry-aware finalization for built-in and extension-routed card.
    func performForwardPaymentCartPurchase(
        executeId: String,
        event: RoktUXEvent.CartItemForwardPayment
    ) {
        if paymentOrchestrator.isBuiltInCardForwardPaymentInFlight() {
            RoktLogger.shared.warning(
                "Forward payment cart purchase ignored while a request is already in flight."
            )
            return
        }

        let cardStepOneCompletion = paymentOrchestrator.beginBuiltInCardForwardPaymentIfReady()
        let builtInDeferredTwoStepActive = cardStepOneCompletion != nil

        let fulfillmentDetails = event.transactionData?.shippingAddress.map {
            FulfillmentDetails(shippingAttributes: ShippingAttributes(from: $0))
        }
        guard let request = RoktInternalImplementation.buildForwardPaymentRequest(
            from: event,
            fulfillmentDetails: fulfillmentDetails
        ) else {
            RoktLogger.shared.warning(
                "Forward payment cart purchase skipped: forward-payment event missing price or has non-positive quantity"
            )
            if builtInDeferredTwoStepActive {
                paymentOrchestrator.finishBuiltInCardForwardPaymentAttempt(
                    result: .failed(error: missingPriceFailureReason)
                )
            }
            paymentOrchestrator.cancelPendingBuiltInTwoStepIfNeeded()
            finalizeForwardPayment(
                executeId,
                event.layoutId,
                event.catalogItemId,
                false,
                missingPriceFailureReason
            )
            return
        }

        emitRoktEvent(executeId, RoktEvent.ShowLoadingIndicator())

        RoktAPIHelper.forwardPayment(
            request: request,
            success: { response in
                self.emitRoktEvent(executeId, RoktEvent.HideLoadingIndicator())
                let finalization = self.resolveCartPurchaseFinalization(response)
                self.handleCartPurchaseHTTP200Response(
                    builtInDeferredTwoStepActive: builtInDeferredTwoStepActive,
                    finalization: finalization,
                    executeId: executeId,
                    event: event,
                    cardStepOneCompletion: cardStepOneCompletion
                )
            },
            failure: { error, statusCode, message in
                self.emitRoktEvent(executeId, RoktEvent.HideLoadingIndicator())
                self.handleCartPurchaseTransportFailure(
                    builtInDeferredTwoStepActive: builtInDeferredTwoStepActive,
                    error: error,
                    statusCode: statusCode,
                    message: message,
                    executeId: executeId,
                    event: event,
                    cardStepOneCompletion: cardStepOneCompletion
                )
            }
        )
    }

    private func handleCartPurchaseHTTP200Response(
        builtInDeferredTwoStepActive: Bool,
        finalization: (success: Bool, failureReason: String?),
        executeId: String,
        event: RoktUXEvent.CartItemForwardPayment,
        cardStepOneCompletion: ((PaymentSheetResult) -> Void)?
    ) {
        if builtInDeferredTwoStepActive {
            if finalization.success {
                paymentOrchestrator.finishBuiltInCardForwardPaymentAttempt(
                    result: .succeeded(transactionId: "")
                )
                finalizeForwardPayment(
                    executeId,
                    event.layoutId,
                    event.catalogItemId,
                    true,
                    nil
                )
            } else if ForwardPaymentRetryRules.isForwardPaymentBusinessFailureRetryable(
                failureReason: finalization.failureReason
            ) {
                paymentOrchestrator.restoreBuiltInCardForwardPaymentAfterRetryableFailure()
            } else {
                paymentOrchestrator.finishBuiltInCardForwardPaymentAttempt(
                    result: .failed(error: finalization.failureReason ?? unknownFailureReason)
                )
                finalizeForwardPayment(
                    executeId,
                    event.layoutId,
                    event.catalogItemId,
                    false,
                    finalization.failureReason
                )
            }
        } else {
            // Extension-routed card (e.g. Stripe `paymentProvider`): no built-in two-step state to restore;
            // on retryable business failure skip `finalizeForwardPayment` so the buyer can confirm again.
            if finalization.success {
                cardStepOneCompletion?(.succeeded(transactionId: ""))
                finalizeForwardPayment(
                    executeId,
                    event.layoutId,
                    event.catalogItemId,
                    true,
                    nil
                )
            } else if ForwardPaymentRetryRules.isForwardPaymentBusinessFailureRetryable(
                failureReason: finalization.failureReason
            ) {
                return
            } else {
                cardStepOneCompletion?(
                    .failed(error: finalization.failureReason ?? unknownFailureReason)
                )
                finalizeForwardPayment(
                    executeId,
                    event.layoutId,
                    event.catalogItemId,
                    false,
                    finalization.failureReason
                )
            }
        }
    }

    private func handleCartPurchaseTransportFailure(
        builtInDeferredTwoStepActive: Bool,
        error: Error,
        statusCode: Int?,
        message: String,
        executeId: String,
        event: RoktUXEvent.CartItemForwardPayment,
        cardStepOneCompletion: ((PaymentSheetResult) -> Void)?
    ) {
        let finalization = resolveTransportFailureFinalization(message)
        if builtInDeferredTwoStepActive {
            if ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: error, statusCode: statusCode) {
                paymentOrchestrator.restoreBuiltInCardForwardPaymentAfterRetryableFailure()
            } else {
                paymentOrchestrator.finishBuiltInCardForwardPaymentAttempt(
                    result: .failed(error: finalization.failureReason ?? unknownFailureReason)
                )
                finalizeForwardPayment(
                    executeId,
                    event.layoutId,
                    event.catalogItemId,
                    false,
                    finalization.failureReason
                )
            }
        } else {
            if ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: error, statusCode: statusCode) {
                return
            }
            cardStepOneCompletion?(
                .failed(error: finalization.failureReason ?? unknownFailureReason)
            )
            finalizeForwardPayment(
                executeId,
                event.layoutId,
                event.catalogItemId,
                false,
                finalization.failureReason
            )
        }
    }
}
