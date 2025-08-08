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
            url: "https://github.com/ROKT/rokt-sdk-ios/releases/download/4.12.1/Rokt_Widget.xcframework.zip",
            checksum: "8b68e0cd17e0427b26cffa79fde02561a67fb44de1a8a9b98c2a90d00eadcd97")
    ]
)