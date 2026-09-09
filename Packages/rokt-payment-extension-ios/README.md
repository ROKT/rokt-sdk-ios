# Rokt Payment Extension (iOS)

Optional payment integration for the Rokt iOS SDK ecosystem. Currently provides
Apple Pay, card, and Afterpay/Clearpay support via Stripe for
[Shoppable Ads](https://docs.rokt.com) placements. Designed to host additional
providers (e.g. PayPal, Klarna) over time.

This package depends only on [RoktContracts](https://github.com/ROKT/rokt-contracts-apple) — not the full Rokt SDK — keeping payment-provider SDKs isolated and the integration lightweight.

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+
- Stripe account with Apple Pay enabled (for Apple Pay / card)
- For Afterpay / Clearpay: a Stripe account with the method enabled, plus a return
  URL the browser can hand back to your app — either (recommended) an https
  universal link under one of your app's Associated Domains (pass it via
  `universalLinkReturnURL:`), or a custom URL scheme registered in the host app's
  `Info.plist` under `CFBundleURLSchemes` (pass the same scheme via `urlScheme:`)

## Installation

### Swift Package Manager

In Xcode: **File > Add Packages**, enter:

```text
https://github.com/ROKT/rokt-payment-extension-ios.git
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ROKT/rokt-payment-extension-ios.git", from: "1.0.0")
]
```

### CocoaPods

```ruby
pod 'RoktPaymentExtension'
```

## Usage

The extension accepts optional init params — you enable only the methods you
want to support. At least one of `applePayMerchantId`, `universalLinkReturnURL`,
or `urlScheme` must be provided; otherwise the initializer returns `nil`.
`universalLinkReturnURL` and `urlScheme` are mutually exclusive — passing both
also returns `nil`.

| Init parameters                                      | Enables                   |
| ---------------------------------------------------- | ------------------------- |
| `applePayMerchantId` only                            | Apple Pay, card           |
| `universalLinkReturnURL` only (recommended)          | Afterpay / Clearpay       |
| `urlScheme` only                                     | Afterpay / Clearpay       |
| `applePayMerchantId` + one of the two return options | Apple Pay, card, Afterpay |

### Direct Rokt SDK Integration

When using the Rokt SDK directly, the partner provides the Stripe publishable key
explicitly at registration time:

```swift
import Rokt_Widget
import RoktPaymentExtension

// 1. Initialize Rokt
Rokt.initWith(roktTagId: "your-tag-id")

// 2. Create the payment extension.
//    Supply `applePayMerchantId` for Apple Pay, `universalLinkReturnURL` (or
//    `urlScheme`) for Afterpay, or both.
guard let paymentExtension = RoktPaymentExtension(
    applePayMerchantId: "merchant.com.example",
    universalLinkReturnURL: URL(string: "https://www.example.com/rokt/payment-return")
    // omit to keep the extension Apple-Pay-only
) else { return }

// 3. Register with the Rokt SDK — pass your Stripe publishable key
Rokt.registerPaymentExtension(paymentExtension, config: [
    "stripeKey": "pk_live_abc123"
])

// 4. Show Shoppable Ads (always overlay)
Rokt.selectShoppableAds(
    identifier: "ConfirmationPage",
    attributes: [
        "email": "user@example.com",
        "firstname": "John",
        "lastname": "Doe",
        "confirmationref": "ORDER-12345"
    ],
    onEvent: { event in
        switch event {
        case let e as RoktEvent.CartItemInstantPurchase:
            print("Purchase: \(e.catalogItemId)")
        case let e as RoktEvent.CartItemInstantPurchaseFailure:
            print("Failed: \(e.error ?? "unknown")")
        default:
            break
        }
    }
)
```

### SDK+ Integration

When using the mParticle SDK, the Stripe publishable key is **automatically provided
from the mParticle dashboard configuration**. The partner only needs to create the
extension and register it — the Kit injects the `stripeKey` before forwarding to the
Rokt SDK:

```swift
import mParticle_Apple_SDK
import RoktPaymentExtension

// 1. mParticle init handles Rokt.initialize via Kit (tagId from dashboard)

// 2. Create and register the payment extension — no stripeKey needed.
guard let paymentExtension = RoktPaymentExtension(
    applePayMerchantId: "merchant.com.example",
    universalLinkReturnURL: URL(string: "https://www.example.com/rokt/payment-return")
    // omit to keep the extension Apple-Pay-only
) else { return }
MParticle.sharedInstance().rokt.registerPaymentExtension(paymentExtension)
// Kit automatically injects stripeKey from dashboard config

// 3. Show Shoppable Ads
MParticle.sharedInstance().rokt.shoppableAds(
    "ConfirmationPage",
    attributes: [
        "email": "user@example.com",
        "firstname": "John",
        "lastname": "Doe"
    ]
)
```

### Enabling Afterpay / Clearpay

Afterpay/Clearpay is a redirect-based payment method: Stripe opens a web page for
authentication and then redirects the browser to a return URL that brings the
user back to your app. Two return-URL options are supported; configure exactly
one. Omit both and the extension stays Apple-Pay-only.

#### Option A — universal link (recommended)

An https URL under one of your app's Associated Domains. iOS delivers a universal
link only to the app whose entitlement claims that domain, so it is the return
URL to use in production.

1. **Host an `apple-app-site-association` file** on the domain (e.g.
   `https://www.example.com/.well-known/apple-app-site-association`) whose
   `applinks` section covers the return path (e.g. `/rokt/payment-return`).
2. **Add the Associated Domains entitlement** to your app target:
   `applinks:www.example.com`.
3. **Pass the return URL** when creating the extension:

   ```swift
   universalLinkReturnURL: URL(string: "https://www.example.com/rokt/payment-return")
   ```

   The URL must be plain `https` with a host and no query, fragment, or
   credentials — Stripe appends its own query on return, and the SDK matches the
   incoming URL on scheme, host, port, and path only. The initializer returns `nil`
   (and raises an `assertionFailure` in DEBUG builds) if the URL is not of that
   form, or if `urlScheme` is passed as well.

4. **Forward universal links** to the Rokt SDK. They arrive through the
   user-activity delegate methods (and through SwiftUI `.onOpenURL`, which
   already receives both universal links and custom-scheme URLs):

   ```swift
   // AppDelegate
   func application(
       _ application: UIApplication,
       continue userActivity: NSUserActivity,
       restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
   ) -> Bool {
       guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
             let url = userActivity.webpageURL else { return false }
       return Rokt.handleURLCallback(with: url)
   }

   // SceneDelegate
   func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
       guard let url = userActivity.webpageURL else { return }
       Rokt.handleURLCallback(with: url)
   }
   ```

5. **Serve a fallback page** at the return URL. If the link ever opens in the
   browser instead of your app (for example when the association file cannot be
   fetched), the user sees that page inside the in-app browser; show a
   "return to the app" message. The payment itself still completes when the
   app returns to the foreground.

#### Option B — custom URL scheme

Custom URL schemes are not exclusive to one app, so prefer Option A in
production and use this option only when you cannot host a universal link.

1. **Declare the URL scheme** in your host app's `Info.plist` under
   `CFBundleURLTypes` (e.g. `myapp`).
2. **Pass the matching `urlScheme`** when creating the extension
   (e.g. `"myapp"`). The SDK builds the full return URL
   (`myapp://rokt-payment-return`) internally — you never need to type the
   path. The initializer returns `nil` if the scheme isn't registered in
   `Info.plist` (and raises an `assertionFailure` in DEBUG builds).
3. **Forward redirect URLs** to the Rokt SDK from your `SceneDelegate` /
   `AppDelegate`:

   ```swift
   // SceneDelegate
   func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
       for ctx in URLContexts {
           Rokt.handleURLCallback(with: ctx.url)
       }
   }
   ```

With either option the SDK dispatches the URL to every registered
`PaymentExtension` via the optional `handleURLCallback(with:)` hook; this
extension forwards only URLs matching its configured return URL to
`StripeAPI.handleURLCallback(with:)` and returns `false` for everything else.

### What Partners Need for Each Scenario

| Scenario                     | Packages                           | Stripe Key Source             | Code                                                                 |
| ---------------------------- | ---------------------------------- | ----------------------------- | -------------------------------------------------------------------- |
| Standard placements (SDK+)   | mParticle SDK + Rokt Kit           | —                             | `rokt.selectPlacements(...)`                                         |
| Shoppable Ads (SDK+)         | Above + RoktPaymentExtension       | Dashboard config (automatic)  | `registerPaymentExtension(ext)` + `shoppableAds(...)`                |
| Standard placements (Direct) | Rokt-Widget                        | —                             | `Rokt.selectPlacements(...)`                                         |
| Shoppable Ads (Direct)       | Rokt-Widget + RoktPaymentExtension | Partner passes in config dict | `registerPaymentExtension(ext, config:)` + `selectShoppableAds(...)` |

For Apple Pay, the extension now uses the backend preparation response to show
shipping, tax, and final total line items in the PassKit sheet whenever those
amounts are supplied.

## Architecture

```text
RoktPaymentExtension (public facade)
  ├── StripeApplePayManager (Apple Pay / card)       ← built if applePayMerchantId provided
  │    ├── STPApplePayContext (Stripe SDK)
  │    └── ContactAddressMapping (PKContact → ContactAddress)
  ├── StripeAfterpayManager (Afterpay / Clearpay)    ← built if universalLinkReturnURL or urlScheme provided
  │    ├── STPPaymentHandler (Stripe SDK)
  │    └── BillingDetailsMapping (ContactAddress → Stripe billing/shipping)
  └── handleURLCallback(with:) → StripeAPI.handleURLCallback
```

- **RoktPaymentExtension**: Implements `PaymentExtension` protocol from RoktContracts; routes each `PaymentMethodType` to the matching internal manager. `supportedMethods` is computed from the configured managers.
- **StripeApplePayManager**: Manages Apple Pay / card flows via Stripe's `STPApplePayContext`, including line-item totals from the backend payment preparation response.
- **StripeAfterpayManager**: Manages redirect-based Afterpay / Clearpay flows via `STPPaymentHandler`; validates `PaymentContext.billingAddress` and confirms the PaymentIntent with the configured return URL — the partner's `universalLinkReturnURL` verbatim, or `<urlScheme>://rokt-payment-return`.
- **ContactAddressMapping**: Converts Apple Pay `PKContact` to `ContactAddress`.
- **BillingDetailsMapping**: Converts `ContactAddress` to `STPPaymentMethodBillingDetails` and `STPPaymentIntentShippingDetailsParams`.

## Migration

See [MIGRATING.md](MIGRATING.md) for migration guidance between major versions.

## License

Copyright 2024 Rokt Pte Ltd. Licensed under the [Rokt SDK Terms of Use 2.0](https://rokt.com/sdk-license-2-0/).

## Security

Please report vulnerabilities via our [disclosure form](https://www.rokt.com/vulnerability-disclosure/). Do not use GitHub issues.
