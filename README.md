# Rokt iOS SDK

The Rokt iOS SDK enables you to integrate Rokt into your native iOS mobile apps to drive more value from, and for, your customers. The SDK is built to be lightweight, secure, and simple to integrate and maintain, resulting in minimal lift for your engineering team.

For more information please visit [official docs](https://docs.rokt.com/docs/developers/integration-guides/ios/overview)

## License

Copyright 2020 Rokt Pte Ltd

Licensed under the Rokt Software Development Kit (SDK) Terms of Use
Version 2.0 (the "License")

You may not use this file except in compliance with the License.

You may obtain a copy of the License at [https://rokt.com/sdk-license-2-0/](https://rokt.com/sdk-license-2-0/)

## Requirements

Download the latest version of [Xcode](https://developer.apple.com/xcode/). Xcode 11 and above comes with a [built-in Swift Package Manager](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

For more information on Swift Package Manager, open [Swift official documentation](https://swift.org/package-manager/)

## Project structure

- `Package.swift` — main package manifest for Swift Package Manager
- `Sources/Rokt_Widget/` — SDK source (source-based distribution via SPM)
- `Packages/` — monorepo copies of UX Helper and Payment Extension (see `MONOREPO.md`)
- `Example/` — sample app demonstrating SDK integration

## How to install

### Swift Package Manager (recommended)

The SDK is distributed as source via SPM for full debuggability.

In Xcode:

- Go to File > Add Packages
- Enter Package URL `https://github.com/ROKT/rokt-sdk-ios.git`
- Select _Up to Next Major_ with _5.0.0_

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ROKT/rokt-sdk-ios.git", .upToNextMajor(from: "5.0.0"))
]
```

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'Rokt-Widget'
```

## How to test integration

The following steps test an overlay placement - only 2 explicit calls, `initWith` and `selectPlacements`, are needed.

### 1. Initialise module for testing

```swift
import Rokt_Widget

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    Rokt.initWith(roktTagId: "your_tag_id_here")
    return true
}
```

Contact Rokt for the Rokt Account ID associated with your account and enter your unique Rokt Account ID as the `roktTagId`.

### 2. Select placements (overlay example)

To test your integration with an overlay placement, firstly define in `ViewController` e.g.

```swift
func showWidget() {
    let attributes = [
        "email": "[your_email_here@email.com]",
        "firstname": "Jenny",
        "lastname": "Smith",
        "mobile": "(555)867-5309",
        "postcode": "90210",
        "country": "US",
        "sandbox": "true"
    ]

    Rokt.selectPlacements(
        identifier: "[your_view_name_here]",
        attributes: attributes
    ) { event in
        switch event {
        case is RoktEvent.ShowLoadingIndicator:
            // Optional callback to show a loading indicator
            break
        case is RoktEvent.HideLoadingIndicator:
            // Optional callback to hide a loading indicator
            break
        case let sizeChanged as RoktEvent.EmbeddedSizeChanged:
            // For embedded placements, use `identifier` and `updatedHeight`
            print("Placement \(sizeChanged.identifier) height: \(sizeChanged.updatedHeight)")
        default:
            break
        }
    }
}
```

Replace `identifier` in the above snippet with your configured view name.

**Important:** Before launching in production, remove `"sandbox": "true"`. The [sandbox environment](https://docs.rokt.com/developers/integration-guides/ios/reference/sandbox-integration/) is intended for acceptance testing, meaning that while it follows the production configuration, it does not charge advertisers or generate revenue.

Finally, call this function in **any subsequent view** where the placement needs to be shown. Placement will not appear when called in the first view of the application as initialization requires time.

To test your integration with embedded placement, [view steps here](https://docs.rokt.com/developers/integration-guides/ios/how-to/adding-a-placement#embedded-placements)

## Session management on self-service terminals

Rokt sessions are managed automatically: placements shown to the same user share one session, and the session survives app restarts. No session code is needed for a normal single-user app.

On a **self-service terminal** — a kiosk, counter tablet, or shared point-of-sale device — a queue of unrelated customers uses one device, and each transaction should be its own session. Call `clearSession()` at the transaction boundary so the next customer starts fresh:

```swift
// The customer has finished at the terminal; the next person starts fresh.
Rokt.clearSession()
```

Behaviour to be aware of:

- **When to call it:** at the boundary between customers — not between screens within one customer's journey. Two placements shown to the same customer are meant to share a session.
- **When the new session begins:** on the next `selectPlacements` call. `clearSession()` only ends the current session; the next placement starts the new one.
- **What it clears:** the stored session, session-scoped events, and cached experiences. The id returned by `getSessionId()` becomes `nil`, so a WebView session hand-off must be re-established afterwards.
- **Calling it is always safe:** with no active session it is a no-op, and repeated calls are idempotent.
- **Experience caching:** avoid enabling `RoktConfig` experience caching on shared terminals — a cached experience belongs to the customer it was fetched for.

**mParticle integrations** get this automatically: the Rokt kit ends the session when the mParticle user changes — a different user identifying or logging in, or the current user logging out. An anonymous user being identified is treated as the same person and keeps the session. Calling `clearSession()` as well is safe; both paths converge on the same idempotent reset.

## Shoppable Ads and payment extensions

For Shoppable Ads, implement the payment contract from **RoktContracts** and register it before showing the placement:

- **Swift:** conform to `PaymentExtension` and call `Rokt.registerPaymentExtension(_:config:)`, then `Rokt.selectShoppableAds(identifier:attributes:...)`.
- **Objective-C:** conform to `RoktPaymentExtension` and use `+[Rokt registerPaymentExtension:config:]` (pass an empty dictionary if you have no config keys). Then `selectShoppableAdsWithIdentifier:attributes:config:onEvent:`.

Wire strings for supported methods (for example `apple_pay`, `card`) and full API details are documented in the [RoktContracts](https://github.com/ROKT/rokt-contracts-apple) package. For broader integration guidance, use the [official iOS docs](https://docs.rokt.com/docs/developers/integration-guides/ios/overview).

## Example app

Open `Example/rokt.xcodeproj` in Xcode to run the sample app. It demonstrates overlay, embedded, and grouped placements with MOCK, STAGE, and PROD configurations.
