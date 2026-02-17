import Foundation
import ObjectiveC

// MARK: - Constants (kept file-private or internal as appropriate)

private let stripeApplePayContextClassName = "STPApplePayContext"
private let stripeInitSelector = "initWithPaymentRequest:delegate:"

private let BE_IS_STRIPE_APPLE_PAY_AVAILABLE_KEY = "stripeApplePayAvailable"

// MARK: - Stripe Capability Checker Protocol and Implementation

protocol StripeCapabilityChecker {
  func isStripeApplePayAvailable() -> Bool
}

/**
 Runtime implementation of Stripe capability checking.

 Uses Objective-C runtime reflection to detect Stripe SDK classes and methods without importing the Stripe framework.

 See [Stripe iOS Documentation](https://stripe.dev/stripe-ios/stripe/documentation/stripe).
 */

class RuntimeStripeCapabilityChecker: StripeCapabilityChecker {

  func isStripeApplePayAvailable() -> Bool {
    guard let applePayContextClass = NSClassFromString(stripeApplePayContextClassName)
    else {
      return false
    }

    let respondsToInit = applePayContextClass.instancesRespond(
      to: NSSelectorFromString(stripeInitSelector))

    return respondsToInit

  }
}

// MARK: - StripeAttributeEnricher

/**
 Detects StripeApplePay integration availability using runtime reflection.
 Enriches attributes sent to Rokt's backend to customize user experience based on payment capabilities.

 - Returns:
  - `false` for `stripeApplePayAvailable` when Stripe Apple Pay is not available.
  - `true` for `stripeApplePayAvailable` when Stripe Apple Pay is available.

 - Testing:
  - Add StripeApplePay dependency to rokt_Example.
  - Import StripeApplePay into the ViewController.
  - Add a breakpoint within getExperienceData() in RoktNetworkAPI.swift
  - Build and run the example application and make an experiences request.
  - Verify that the `stripeApplePayAvailable` attribute is set to `true` when Stripe Apple Pay is available.
  - Verify that the `stripeApplePayAvailable` attribute is set to `false` when Stripe Apple Pay is not available.
 */

class StripeAttributeEnricher: AttributeEnricher {
  private let capabilityChecker: StripeCapabilityChecker

  init(capabilityChecker: StripeCapabilityChecker = RuntimeStripeCapabilityChecker()) {
    self.capabilityChecker = capabilityChecker
  }

  func enrich(config: RoktConfig?) -> [String: String] {
    var enrichedAttributes = [String: String]()

    let isStripeApplePayAvailable = capabilityChecker.isStripeApplePayAvailable()
    enrichedAttributes[BE_IS_STRIPE_APPLE_PAY_AVAILABLE_KEY] = String(isStripeApplePayAvailable)

    return enrichedAttributes
  }
}
