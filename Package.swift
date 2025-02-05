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
                      url: "https://apps.rokt.com/msdk/ios/4.8.0/Rokt_Widget.xcframework.zip",
                      checksum: "7b00800e1de3f8f881d0b72e5d5e9e0ed71e8da308dcefcaef5df07d1fc0afa4")
    ]
)