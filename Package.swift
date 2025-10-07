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
            checksum: "104ae72db6320db49f50ed626995c20a69f9ad138ffe3e7a0acf5398a164c04b")
    ]
)
