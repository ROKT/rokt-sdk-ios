import Foundation
import RoktContracts
import StripePayments
import UIKit

/// The slice of `STPPaymentHandler` the Afterpay flow drives, so the confirmation
/// step can be exercised in tests without Stripe's network stack.
internal protocol AfterpayPaymentConfirming: AnyObject {
    var apiClient: STPAPIClient { get set }

    func confirmPaymentIntent(
        params: STPPaymentIntentParams,
        authenticationContext: STPAuthenticationContext,
        completion: @escaping STPPaymentHandlerActionPaymentIntentCompletionBlock
    )
}

extension STPPaymentHandler: AfterpayPaymentConfirming {}

internal class StripeAfterpayManager {

    private let apiClient: STPAPIClient
    private let returnURL: String
    private let makeConfirmer: () -> AfterpayPaymentConfirming

    /// Retained until the confirmation reaches a terminal status so the handler
    /// survives the redirect round-trip.
    private(set) var activeConfirmer: AfterpayPaymentConfirming?

    internal init(
        apiClient: STPAPIClient,
        returnURL: String,
        makeConfirmer: @escaping () -> AfterpayPaymentConfirming = { STPPaymentHandler.shared() }
    ) {
        self.apiClient = apiClient
        self.returnURL = returnURL
        self.makeConfirmer = makeConfirmer
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

            let extensionClient = self.apiClient
            extensionClient.stripeAccount = preparation.merchantId

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

            let confirmer = self.makeConfirmer()
            self.activeConfirmer = confirmer

            DispatchQueue.main.async {
                // Stripe exposes no public per-instance STPPaymentHandler initializer, so the
                // shared handler is borrowed: pointed at the extension-owned client for this
                // confirmation and handed back with the host app's client on every outcome.
                // STPAPIClient.shared is never read or written.
                let hostClient = confirmer.apiClient
                confirmer.apiClient = extensionClient

                confirmer.confirmPaymentIntent(
                    params: params,
                    authenticationContext: authContext
                ) { [weak self] status, intent, error in
                    confirmer.apiClient = hostClient
                    self?.activeConfirmer = nil

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
