# Rokt iOS SDK

The Rokt iOS SDK enables you to integrate Rokt into your native iOS mobile apps to drive more value from, and for, your customers. The SDK is built to be lightweight, secure, and simple to integrate and maintain, resulting in minimal lift for your engineering team.

For more information please visit [official docs](https://docs.rokt.com/docs/developers/integration-guides/ios/overview)

## License

Copyright 2020 Rokt Pte Ltd

Licensed under the Rokt Software Development Kit (SDK) Terms of Use
Version 2.0 (the "License")

You may not use this file except in compliance with the License.

You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

## Requirements

Download the latest version of [Xcode](https://developer.apple.com/xcode/). Xcode 11 and above comes with a [built-in Swift Package Manager](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

For more information on Swift Package Manager, open [Swift official documentation](https://swift.org/package-manager/)

## Project structure

- `Package.swift` — main package manifest for Swift Package Manager
- `Sources/Rokt_Widget/` — SDK source (source-based distribution via SPM)
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

## Example app

Open `Example/rokt.xcodeproj` in Xcode to run the sample app. It demonstrates overlay, embedded, and grouped placements with MOCK, STAGE, and PROD configurations.
