import Foundation
import RoktContracts
internal import RoktUXHelper

/// Runs built-in card forwarding after device-pay confirm: begin session, POST `/v1/cart/purchase`,
/// apply card forwarding retry policy, and notify the host for loading / UX finalization.
final class BuiltInCardForwardingPurchaseCoordinator {
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

    /// Runs the forward-payment cart purchase (`/v1/cart/purchase`) for card forwarding:
    /// in-flight guard, request build, API call, retry handling, and host callbacks.
    func performCardForwardingCartPurchase(
        executeId: String,
        event: RoktUXEvent.CartItemForwardPayment
    ) {
        if paymentOrchestrator.isBuiltInCardForwardPaymentInFlight() {
            RoktLogger.shared.warning(
                "Card forwarding ignored while a cart purchase request is already in flight."
            )
            return
        }

        let cardStepOneCompletion = paymentOrchestrator.beginBuiltInCardForwardPaymentIfReady()
        let cardForwardingFlowActive = cardStepOneCompletion != nil

        let fulfillmentDetails = event.transactionData?.shippingAddress.map {
            FulfillmentDetails(shippingAttributes: ShippingAttributes(from: $0))
        }
        guard let request = RoktInternalImplementation.buildForwardPaymentRequest(
            from: event,
            fulfillmentDetails: fulfillmentDetails
        ) else {
            RoktLogger.shared.warning(
                "Card forwarding cart purchase skipped: forward-payment event missing price or has non-positive quantity"
            )
            if cardForwardingFlowActive {
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
                    cardForwardingFlowActive: cardForwardingFlowActive,
                    finalization: finalization,
                    executeId: executeId,
                    event: event,
                    cardStepOneCompletion: cardStepOneCompletion
                )
            },
            failure: { error, statusCode, message in
                self.emitRoktEvent(executeId, RoktEvent.HideLoadingIndicator())
                self.handleCartPurchaseTransportFailure(
                    cardForwardingFlowActive: cardForwardingFlowActive,
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
        cardForwardingFlowActive: Bool,
        finalization: (success: Bool, failureReason: String?),
        executeId: String,
        event: RoktUXEvent.CartItemForwardPayment,
        cardStepOneCompletion: ((PaymentSheetResult) -> Void)?
    ) {
        if cardForwardingFlowActive {
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
            } else if CardForwardingRetryRules.isCardForwardingErrorRetryable(failureReason: finalization.failureReason) {
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
            if finalization.success {
                cardStepOneCompletion?(.succeeded(transactionId: ""))
            } else {
                cardStepOneCompletion?(
                    .failed(error: finalization.failureReason ?? unknownFailureReason)
                )
            }
            finalizeForwardPayment(
                executeId,
                event.layoutId,
                event.catalogItemId,
                finalization.success,
                finalization.failureReason
            )
        }
    }

    private func handleCartPurchaseTransportFailure(
        cardForwardingFlowActive: Bool,
        error: Error,
        statusCode: Int?,
        message: String,
        executeId: String,
        event: RoktUXEvent.CartItemForwardPayment,
        cardStepOneCompletion: ((PaymentSheetResult) -> Void)?
    ) {
        let finalization = resolveTransportFailureFinalization(message)
        if cardForwardingFlowActive {
            if CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: error, statusCode: statusCode) {
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
