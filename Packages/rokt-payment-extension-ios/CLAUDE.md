# RoktPaymentExtension

Stripe payment extension implementing `PaymentExtension` protocol from RoktContracts.

## Build & Test

```bash
# Build (iOS simulator — UIKit dependency)
swift build --sdk $(xcrun --sdk iphonesimulator --show-sdk-path) --triple arm64-apple-ios15.0-simulator

# Test
xcodebuild test \
  -scheme RoktPaymentExtension \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
  -skipPackagePluginValidation

# Lint
trunk check --all
trunk fmt --all

# Pod lint
pod lib lint RoktPaymentExtension.podspec --allow-warnings
```

## Architecture

Public facade → StripeApplePayManager → Stripe SDK (STPApplePayContext)

- `RoktPaymentExtension`: Public class implementing `PaymentExtension`
- `StripeApplePayManager`: Internal Apple Pay orchestration
- `ContactAddressMapping`: PKContact → ContactAddress conversion

## Dependencies

- **RoktContracts**: Protocol + payment types (PaymentExtension, PaymentItem, PaymentResult, etc.)
- **StripeApplePay**: Apple Pay context and delegate
- **StripeCore**: Stripe API client

## Key Patterns

- Failable init (`init?`) guards against empty merchant ID
- `onRegister` creates Stripe API client from publishable key
- `presentPaymentSheet` delegates to StripeApplePayManager
- Async `preparePayment` callback bridged to delegate via `Task { }`
- `objc_setAssociatedObject` retains delegate during Apple Pay flow
