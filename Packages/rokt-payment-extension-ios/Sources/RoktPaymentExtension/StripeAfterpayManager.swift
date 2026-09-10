import Foundation
import RoktContracts
import StripePayments
import UIKit

internal class StripeAfterpayManager {

    private let apiClient: STPAPIClient
    internal let returnURL: String

    /// True from the moment a confirmation is handed to Stripe until its completion runs, so a
    /// second tap in that window fails instead of starting another confirmation. Main queue only.
    private var isConfirming = false

    internal init(apiClient: STPAPIClient, returnURL: String) {
        self.apiClient = apiClient
        self.returnURL = returnURL
    }

    internal func presentPayment(
        item: PaymentItem,
        context: PaymentContext,
        from viewController: UIViewController,
        preparePayment: @escaping (
            _ address: ContactAddress,
            _ completion: @escaping (PaymentPreparation?, Error?) -> Void
        ) -> Void,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        guard !item.name.isEmpty else {
            completion(.failed(error: "Payment item name cannot be empty"))
            return
        }

        guard !item.id.isEmpty else {
            completion(.failed(error: "Payment item id cannot be empty"))
            return
        }

        guard item.amount.compare(NSDecimalNumber.zero) == .orderedDescending else {
            completion(.failed(error: "Payment item amount must be greater than zero"))
            return
        }

        guard !item.currency.isEmpty else {
            completion(.failed(error: "Payment item currency cannot be empty"))
            return
        }

        // Afterpay requires billing details. If the partner only supplies a
        // shipping address, fall back to that so the payment can still be
        // confirmed.
        guard let billingAddress = context.billingAddress ?? context.shippingAddress else {
            completion(.failed(
                error: "Afterpay requires a billing or shipping address. Provide at least one in PaymentContext."
            ))
            return
        }

        guard let billingName = BillingDetailsMapping.resolvedName(
            billingAddress.name,
            fallback: context.shippingAddress?.name
        ) else {
            completion(.failed(
                error: "Afterpay requires a billing or shipping name. Provide a non-empty name in PaymentContext."
            ))
            return
        }

        // Call preparePayment with the pre-collected address before showing any UI
        preparePayment(billingAddress) { [weak self] preparation, error in
            guard let self else { return }

            if let error, preparation == nil {
                completion(.failed(error: error.localizedDescription))
                return
            }

            guard let preparation else {
                completion(.failed(error: "Payment preparation returned nil"))
                return
            }

            let params = STPPaymentIntentParams(clientSecret: preparation.clientSecret)
            params.paymentMethodParams = STPPaymentMethodParams(
                afterpayClearpay: STPPaymentMethodAfterpayClearpayParams(),
                billingDetails: BillingDetailsMapping.map(from: billingAddress, fallbackName: billingName),
                metadata: nil
            )
            params.returnURL = self.returnURL

            if let shippingAddress = context.shippingAddress {
                params.shipping = BillingDetailsMapping.mapShipping(from: shippingAddress, fallbackName: billingName)
            }

            let authContext = SimpleAuthenticationContext(presentingController: viewController)

            DispatchQueue.main.async {
                guard !self.isConfirming else {
                    completion(.failed(error: "A payment is already in progress"))
                    return
                }
                self.isConfirming = true

                // Stripe exposes one payment handler, so for this confirmation it is pointed at the
                // extension's own client (scoped to the connected account) and afterwards handed back
                // the client it held. STPAPIClient.shared itself is never changed.
                let extensionClient = self.apiClient
                extensionClient.stripeAccount = preparation.merchantId
                let handler = STPPaymentHandler.shared()
                let previousClient = handler.apiClient
                handler.apiClient = extensionClient

                handler.confirmPaymentIntent(
                    params: params,
                    authenticationContext: authContext
                ) { [weak self] status, intent, error in
                    // The redirect and polling steps also run on the handler's client, so the
                    // hand-back waits for the completion and happens on every outcome.
                    handler.apiClient = previousClient
                    extensionClient.stripeAccount = nil
                    self?.isConfirming = false

                    switch status {
                    case .succeeded:
                        completion(.succeeded(transactionId: StripePaymentDiagnostics.transactionId(
                            from: intent,
                            clientSecret: preparation.clientSecret
                        )))
                    case .canceled:
                        completion(.canceled)
                    case .failed:
                        completion(.failed(error: StripePaymentDiagnostics.failureMessage(
                            baseMessage: error?.localizedDescription ?? "Afterpay payment failed",
                            paymentIntent: intent,
                            error: error
                        )))
                    @unknown default:
                        completion(.failed(error: "Unknown payment status"))
                    }
                }
            }
        }
    }
}

// MARK: - STPAuthenticationContext wrapper

private class SimpleAuthenticationContext: NSObject, STPAuthenticationContext {
    private let controller: UIViewController

    init(presentingController: UIViewController) {
        self.controller = presentingController
    }

    func authenticationPresentingViewController() -> UIViewController {
        controller
    }
}
