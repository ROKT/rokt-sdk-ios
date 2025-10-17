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

    private let stripePublishableKey = "pk_test_51QrRbaDg9xZkkBE2WZcoYYO4sDkZTuIL7BcoNX1b6K49zM0I80VlUgAumWIlZV5jIxQe4QxXxHLDvqaiEWq8bki600FXgjAy5k"
    private let countryCode: String
    private let currencyCode: String

    // Remove the stored property and keep only the lazy one
    private lazy var stripeAPIClient: STPAPIClient = {
        return STPAPIClient(publishableKey: stripePublishableKey)
    }()

    private var stripeApplePayManager: StripeApplePayManager?

    // MARK: - Initialization

    public init?(
        applePayMerchantId: String? = nil,
        countryCode: String = "US",
        currencyCode: String = "USD"
    ) {
        guard !stripePublishableKey.isEmpty else {
            return nil
        }

        self.countryCode = countryCode
        self.currencyCode = currencyCode

        // Initialize Apple Pay manager if merchant ID provided
        if let merchantId = applePayMerchantId {
            self.stripeApplePayManager = StripeApplePayManager(
                apiClient: stripeAPIClient,
                merchantId: merchantId,
                countryCode: countryCode,
                currencyCode: currencyCode
            )
        } else {
            self.stripeApplePayManager = nil
        }
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
        let error = PaymentError(
            code: "IOS_VERSION_INCOMPATIBLE",
            message:
            "Stripe SDK requires iOS 13.0 or later. Current version: \(UIDevice.current.systemVersion)"
        )
        completion(PaymentResult(success: false, error: error))
        return
      }

        guard let stripeApplePayManager = stripeApplePayManager else {
          let error = PaymentError(
              code: "APPLE_PAY_NOT_CONFIGURED",
              message:
              "Apple Pay not configured. Please provide applePayMerchantId during initialization."
          )
          completion(PaymentResult(success: false, error: error))
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
