//
//  StripeApplePayManager.swift
//
//  Copyright 2020 Rokt Pte Ltd
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import Foundation
import PassKit
import Rokt_Widget
import StripeApplePay

internal class StripeApplePayManager: NSObject {

    private let apiClient: STPAPIClient
    private let merchantId: String
    private let countryCode: String
    private let currencyCode: String

    internal init(
        apiClient: STPAPIClient,
        merchantId: String,
        countryCode: String = "US",
        currencyCode: String = "USD"
    ) {
        self.apiClient = apiClient
        self.merchantId = merchantId
        self.countryCode = countryCode
        self.currencyCode = currencyCode
    }

    public func presentPayment(
        item: PaymentItem,
        from viewController: UIViewController,
        preparePayment: @escaping PreparePayment,
        completion: @escaping (PaymentResult) -> Void
    ) {
        guard !item.name.isEmpty,
            !item.catalogItemId.isEmpty,
            item.quantity > 0,
            item.unitPrice > 0
        else {
            completion(PaymentResult(success: false, message: "Payment item has invalid properties"))
            return
        }

        guard !merchantId.isEmpty else {
            completion(PaymentResult(success: false, message: "Merchant ID cannot be empty"))
            return
        }

        guard PKPaymentAuthorizationController.canMakePayments() else {
            completion(PaymentResult(success: false, message: "Apple Pay is not available on this device"))
            return
        }

        guard item.totalPrice > 0 else {
            completion(PaymentResult(success: false, message: "Item price must be greater than zero"))
            return
        }

        // Create initial payment request
        let paymentRequest = createPaymentRequest(item: item)

        // Create delegate with the API client
        let delegate = StripeApplePayDelegate(
            apiClient: apiClient,
            preparePayment: preparePayment,
            completion: completion
        )

        guard
            let applePayContext = STPApplePayContext(
                paymentRequest: paymentRequest,
                delegate: delegate
            )
        else {
            completion(PaymentResult(success: false, message: "Failed to create Apple Pay context"))
            return
        }

        // Configure the context to use our custom API client
        applePayContext.apiClient = apiClient

        // Store delegate reference to prevent deallocation
        objc_setAssociatedObject(applePayContext, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        // Present Apple Pay
        applePayContext.presentApplePay {
            // Apple Pay presentation started
        }
    }

    private func createPaymentRequest(item: PaymentItem) -> PKPaymentRequest {
        let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex, .discover]
        let merchantCapabilities: PKMerchantCapability = [
            .capability3DS, .capabilityCredit, .capabilityDebit
        ]

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantId
        request.countryCode = countryCode
        request.currencyCode = currencyCode.uppercased()
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = merchantCapabilities

        // Enforce shipping address collection
        request.requiredShippingContactFields = [.postalAddress, .name, .phoneNumber, .emailAddress]

        // Enforce billing address collection
        request.requiredBillingContactFields = [.postalAddress, .name]

        request.paymentSummaryItems = createPaymentSummaryItems(
            subtotal: item.unitPrice * item.quantity,
            total: item.totalPrice
        )

        return request
    }
}

private func createPaymentSummaryItems(
    subtotal: Decimal,
    tax: Decimal = 0,
    shipping: Decimal = 0,
    total: Decimal,
    totalLabel: String = ""
) -> [PKPaymentSummaryItem] {
    var items: [PKPaymentSummaryItem] = []

    items.append(
        PKPaymentSummaryItem(
            label: "Subtotal",
            amount: NSDecimalNumber(decimal: subtotal)
        )
    )

    if tax > 0 {
        items.append(
            PKPaymentSummaryItem(
                label: "Tax",
                amount: NSDecimalNumber(decimal: tax)
            )
        )
    }

    if shipping > 0 {
        items.append(
            PKPaymentSummaryItem(
                label: "Shipping",
                amount: NSDecimalNumber(decimal: shipping)
            )
        )
    }

    items.append(
        PKPaymentSummaryItem(
            label: totalLabel,
            amount: NSDecimalNumber(decimal: total)
        )
    )

    return items
}

private class StripeApplePayDelegate: NSObject, ApplePayContextDelegate {
    let apiClient: STPAPIClient
    let preparePayment: PreparePayment
    let completion: (PaymentResult) -> Void

    // Track if payment has been prepared with shipping address
    private var isPaymentPrepared = false
    private var clientSecret: String?
    private var paymentIntentId: String?

    init(apiClient: STPAPIClient, preparePayment: @escaping PreparePayment, completion: @escaping (PaymentResult) -> Void) {
        self.apiClient = apiClient
        self.preparePayment = preparePayment
        self.completion = completion
    }

    func applePayContext(
        _ context: STPApplePayContext,
        didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod,
        paymentInformation: PKPayment,
        completion: @escaping STPIntentClientSecretCompletionBlock
    ) {
        // Check if payment has been prepared with shipping address
        guard isPaymentPrepared, clientSecret != nil else {
            completion(nil, "Payment must be prepared with shipping address before completion")
            return
        }

        // Use the prepared client secret
        completion(clientSecret, nil)
    }

    func applePayContext(
        _ context: STPApplePayContext,
        didCompleteWith status: STPApplePayContext.PaymentStatus,
        error: Error?
    ) {
        switch status {
        case .success:
            let paymentResult = PaymentResult(
                success: true,
                transactionId: paymentIntentId ?? "unknown"
            )
            completion(paymentResult)
        case .error:
            let paymentResult = PaymentResult(
                success: false,
                message: error?.localizedDescription ?? "Unknown error"
            )
            completion(paymentResult)
        case .userCancellation:
            let paymentResult = PaymentResult(
                success: false,
                message: "Apple Pay was canceled by user"
            )
            completion(paymentResult)
        @unknown default:
            let paymentResult = PaymentResult(
                success: false,
                message: "Unknown payment status"
            )
            completion(paymentResult)
        }
    }

    // Method for shipping address updates
    func applePayContext(
        _ context: STPApplePayContext,
        didSelectShippingContact contact: PKContact,
        handler: @escaping (_ update: PKPaymentRequestShippingContactUpdate) -> Void
    ) {
        // Extract shipping address from contact
        let shippingAddress = extractShippingAddress(from: contact)

        // Call preparePayment to get updated pricing
        preparePayment(shippingAddress) { result in
            switch result {
            case .success(let preparation):
                self.isPaymentPrepared = true
                self.clientSecret = preparation.paymentProviderData.getValue(for: "clientSecret")
                self.paymentIntentId = preparation.paymentProviderData.getValue(for: "paymentIntentId")

                let merchantName = preparation.paymentProviderData.getValue(for: "merchantName")

                // Convert string values to Decimal
                let subtotal = Decimal(string: preparation.subtotal) ?? 0
                let tax = Decimal(string: preparation.tax) ?? 0
                let shipping = Decimal(string: preparation.shipping) ?? 0
                let total = Decimal(string: preparation.total) ?? 0

                // Create updated payment summary items
                let updatedItems = createPaymentSummaryItems(
                    subtotal: subtotal,
                    tax: tax,
                    shipping: shipping,
                    total: total,
                    totalLabel: merchantName ?? "Total"
                )

                // Return the update to Apple Pay
                let update = PKPaymentRequestShippingContactUpdate(
                    errors: nil,
                    paymentSummaryItems: updatedItems,
                    shippingMethods: []
                )
                handler(update)

            case .failure(let message):
                // Reset preparation state on message
                self.isPaymentPrepared = false
                self.clientSecret = nil
                self.paymentIntentId = nil

                DispatchQueue.main.async {
                    self.context?.dismiss { }
                    self.completion(PaymentResult(success: false, message: message))
                }
            }
        }
    }

    private func extractShippingAddress(from contact: PKContact) -> ShippingAttributes? {
        guard let postalAddress = contact.postalAddress else {
            return nil
        }

        return ShippingAttributes(
            address1: postalAddress.street,
            city: postalAddress.city,
            state: postalAddress.state,
            postalCode: postalAddress.postalCode,
            country: postalAddress.country,
            firstName: contact.name?.givenName,
            lastName: contact.name?.familyName,
            countryCode: postalAddress.isoCountryCode
        )
    }
}
