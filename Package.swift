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
        .library(
            name: "Rokt_Widget",
            targets: ["Rokt_Widget"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt_Widget",
            url: "https://github.com/rokt/rokt-sdk-ios/raw/test-static-lib/Rokt_Widget.xcframework.zip",
            checksum: "e04513d7a524eec3181ae031d7ff21fc5f525290ee4fd3c157cba679985ad49f")
    ]
)
