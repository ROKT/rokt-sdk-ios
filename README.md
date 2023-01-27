# Rokt iOS SDK

The Rokt iOS SDK enables you to integrate Rokt into your native iOS mobile apps to drive more value from, and for, your customers. The SDK is built to be lightweight, secure, and simple to integrate and maintain, resulting in minimal lift for your engineering team.

## Resident Experts

- Emmanuel Tugado - emmanuel.tugado@rokt.com
- Danial Motahari - danial.motahari@rokt.com

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

`Package.swift` is the [main package manifest](https://developer.apple.com/documentation/packagedescription) that defines updated configurations to the Rokt iOS SDK package as required by the Swift Package Manager.

## How to install

To install for iOS development:

On Xcode: 
* Go to File > Add Packages
* Enter Package URL `https://github.com/ROKT/rokt-sdk-ios.git`
* Select *Up to Next Major* with *3.10.0*

Alternatively add below code to the `dependencies` part of `Package.swift`.
```swift
dependencies: [
    .package(url: "https://github.com/ROKT/rokt-sdk-ios.git", .upToNextMajor(from: "3.10.0"))
]
```

### Note on Objective-C integration

The Rokt SDK for iOS is implemented using Swift. If you are using Objective-C, you need to import the bridging header file from the framework into the .h/.m file.
```objective-c
#import <Rokt_Widget/Rokt_Widget-Swift.h>
```
If you are having trouble installing and are receiving an error saying that the SWIFT_VERSION is not defined, please add a user-defined variable `SWIFT_VERSION`. This variable should be set to `5` for iOS SDK versions 2.0 and above. This variable should be set to `4.2` for iOS SDK version 1.2.1.

## How to test integration

The following steps test an overlay placement - only 2 explicit calls, `init` and `execute`, are needed.

### 1. Initialise module for testing

```swift
import Rokt_Widget

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    Rokt.initWith(roktTagId: "your_tag_id_here")
    return true
}
```

Contact Rokt for the Rokt Account ID associated with your account and enter your unique Rokt Account ID as the `roktTagId`.

### 2. Execute (overlay placement)

Firstly define in `ViewController` e.g.

```swift
func showWidget() {
    let attributes = ["email": "j.smith1674613477652@example.com",
            "firstname": "Jenny",
            "lastname": "Smith",
            "mobile": "(555)867-5309",
            "postcode": "90210",
            "country": "US",
            "sandbox": "true"]

    Rokt.execute(viewName: "your_view_name_here", attributes: attributes, onLoad: {
        // Optional callback for when the Rokt placement loads
    }, onUnLoad: {
        // Optional callback for when the Rokt placement unloads
    }, onShouldShowLoadingIndicator: {
        // Optional callback to show a loading indicator
    }, onShouldHideLoadingIndicator: {
        // Optional callback to hide a loading indicator
    }, onEmbeddedSizeChange: { selectedPlacement, widgetHeight in
        // Optional callback to get selectedPlacement and height required by the placement every time the height of the placement changes
    })
}
```

Replace `viewName` in the above snippet with your configured view name

Finally, call this function when the placement needs to be shown.
**Important** Function needs to be called either in a delay function (snippet below) or on button click to allow some time for initialization.

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    self.showWidget()
}
```

For more information please visit [official docs](https://docs.rokt.com/docs/developers/integration-guides/ios/overview)