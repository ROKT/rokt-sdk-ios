# Rokt iOS SDK

The Rokt iOS SDK enables you to integrate Rokt into your native iOS mobile apps to drive more value from—and for—your customers. The SDK is built to be lightweight, secure, and simple to integrate and maintain, resulting in minimal lift for your engineering team.

## Swift Package Manager Integration

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Add below code to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/ROKT/rokt-sdk-ios.git", .upToNextMajor(from: "3.5.0-alpha.2"))
]
```

For more information please visit [official docs](https://docs.rokt.com/docs/sdk/ios/overview.html)

