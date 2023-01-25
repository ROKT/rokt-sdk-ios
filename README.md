# Rokt iOS SDK

The Rokt iOS SDK enables you to integrate Rokt into your native iOS mobile apps to drive more value from, and for, your customers. The SDK is built to be lightweight, secure, and simple to integrate and maintain, resulting in minimal lift for your engineering team.

## Resident Experts

- Danial Motahari - danial.motahari@rokt.com
- Emmanuel Tugado - emmanuel.tugado@rokt.com

## License

Copyright 2020 Rokt Pte Ltd

Licensed under the Rokt Software Development Kit (SDK) Terms of Use
Version 2.0 (the "License")

You may not use this file except in compliance with the License.

You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

## Requirements

Download the latest version of [Xcode](https://developer.apple.com/xcode/). Xcode 11 and above comes with a [built-in Swift Package Manager](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

For more information on Swift Package Manager open in [Swift official documentation](https://swift.org/package-manager/)

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

Import and initialise module for testing

```swift
//file => AppDelegate.swift

import Rokt_Widget

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    Rokt.initWith(roktTagId: "222")
    return true
}
```

The above uses the Test Rokt Account ID `222` to reveal a demo integration.

**Important:** Before you launch in production, contact Rokt for the Rokt Account ID associated with your account and replace the Test Rokt Account ID with your unique Rokt Account ID.

For more information please visit [official docs](https://docs.rokt.com/docs/developers/integration-guides/ios/overview)