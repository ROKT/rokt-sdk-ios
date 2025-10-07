// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "Rokt-Widget",
            targets: ["Rokt_Widget"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt_Widget",
            url: "https://github.com/rokt/rokt-sdk-ios/raw/test-static-lib/Rokt_Widget.xcframework.zip",
            checksum: "b4969c1c18c1c078b953b0dcf1cbb5c5bb41e5f73b8974f4ea1d680c28d5916b")
    ]
)
