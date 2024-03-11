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
                      url: "https://apps.rokt.com/msdk/ios/4.2.0/Rokt_Widget.xcframework.zip",
                      checksum: "a6d0427780d9b34126e266ae3816142be2df1e6217aab6ec982617a04d2681cf")
    ]
)