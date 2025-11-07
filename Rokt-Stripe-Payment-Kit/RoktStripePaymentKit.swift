//
//  RoktStripePaymentKit.swift
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
import StripeCore
import SwiftUI

public class RoktStripePaymentKit: PaymentKit, ObservableObject {

    // MARK: - PaymentKit Protocol Properties

    public let id: String = "rokt-stripe-payment-kit"
    public let description: String =
        "Rokt Stripe Payment Kit - Secure payment processing with Stripe"
    public let supportedMethods: [PaymentMethodType] = [.applePay, .card]

    // MARK: - Private Properties

    private let merchantId: String
    private let countryCode: String
    private let currencyCode: String

    private var stripeApplePayManager: StripeApplePayManager?

    // MARK: - Initialization

    /// Initialize RoktStripePaymentKit with a Stripe key
    ///
    /// - Parameters:
    ///   - applePayMerchantId: Optional Apple Pay merchant identifier
    ///   - countryCode: Country code for payment (default: "US")
    ///   - currencyCode: Currency code for payment (default: "USD")
    public init?(
        applePayMerchantId: String,
        countryCode: String = "US",
        currencyCode: String = "USD"
    ) {
        if applePayMerchantId.isEmpty {
            return nil
        }

        self.merchantId = applePayMerchantId
        self.countryCode = countryCode
        self.currencyCode = currencyCode
    }

    public func onRegister(parameters: [String: String]) -> Bool {
        guard let stripeKey = parameters["stripeKey"] else {
            return false
        }

        let stripeAPIClient = STPAPIClient(publishableKey: stripeKey)

        self.stripeApplePayManager = StripeApplePayManager(
            apiClient: stripeAPIClient,
            merchantId: merchantId,
            countryCode: countryCode,
            currencyCode: currencyCode
        )

        return true
    }

    public func onUnregister() {
        // No-op
    }

    // MARK: - PaymentKit Protocol Implementation

    public func presentPaymentSheet(
        item: PaymentItem,
        method: PaymentMethodType,
        from viewController: UIViewController,
        preparePayment: @escaping PreparePayment,
        completion: @escaping (PaymentResult) -> Void
    ) {
        guard #available(iOS 13.0, *) else {
            completion(
                PaymentResult(
                    success: false,
                    message:
                        "Stripe SDK requires iOS 13.0 or later. Current version: \(UIDevice.current.systemVersion)"
                ))
            return
        }

        guard let stripeApplePayManager = stripeApplePayManager else {
            completion(
                PaymentResult(
                    success: false,
                    message:
                        "Apple Pay not configured. Please provide applePayMerchantId during initialization."
                ))
            return
        }

        stripeApplePayManager.presentPayment(
            item: item,
            from: viewController,
            preparePayment: preparePayment,
            completion: completion
        )
    }
}
