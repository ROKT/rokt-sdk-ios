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
            url: "https://github.com/ROKT/rokt-sdk-ios/releases/download/4.10.0/Rokt_Widget.xcframework.zip",
            checksum: "dff15bde876070a6b72d86d5f6a65db0d2a42fdd8df8ecb1052be3f0e563c57f")
    ]
)