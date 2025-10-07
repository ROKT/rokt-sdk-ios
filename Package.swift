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
            checksum: "ae7618077a9ed41b319b892eb55abdb758021162b1a1ee6975baed7e35a8838a")
    ]
)
