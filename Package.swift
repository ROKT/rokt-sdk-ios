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
                      url: "https://apps.rokt.com/msdk/ios/4.1.0-beta.8/Rokt_Widget.xcframework.zip",
                      checksum: "04fbd63c045fb11105cd8f76840c1088be0a53b65e0050b424165b6bf64d5de6")
    ]
)