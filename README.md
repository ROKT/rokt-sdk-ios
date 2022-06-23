# Rokt iOS SDK

The Rokt iOS SDK enables you to integrate Rokt into your native iOS mobile apps to drive more value from—and for—your customers. The SDK is built to be lightweight, secure, and simple to integrate and maintain, resulting in minimal lift for your engineering team.

## Swift Package Manager Integration

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

On Xcode: 
* Go to File > Swift Packages > Add Package Dependency
* Add `https://github.com/ROKT/rokt-sdk-ios.git`
* Select *Up to Next Major* with *3.7.0*

or add below code to the `dependencies` part of `Package.swift`.
```swift
dependencies: [
    .package(url: "https://github.com/ROKT/rokt-sdk-ios.git", .upToNextMajor(from: "3.7.0"))
]
```

For more information please visit [official docs](https://docs.rokt.com/docs/developers/integration-guides/ios/overview)

