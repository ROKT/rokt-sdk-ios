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
                      url: "https://apps.rokt.com/msdk/ios/3.17.0/Rokt_Widget.xcframework.zip",
                      checksum: "d1f245a1e5e9672cba267bd65b4c31244e14a130bcaaa8ee44b6239fb8a6fbb6")
    ]
)