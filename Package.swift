// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "Rokt-Widget",
            targets: ["Rokt_Widget"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt_Widget",
            url: "https://github.com/ROKT/rokt-sdk-ios/releases/download/4.16.3/Rokt_Widget.xcframework.zip",
            checksum: "f42ace8a47473a047389348a54404e17d411fdb60cdf526e13d410a3ecbf92e1")
    ]
)