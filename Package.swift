// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "Rokt-Widget",
            targets: ["RoktWidget"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt_Widget",
                      url: "https://apps.rokt.com/msdk/ios/4.2.0-alpha.1/Rokt_Widget.xcframework.zip",
                      checksum: "087cda5d8274ff8d4a410ba8b39977bb803a67dfae75ca387d5e24a6b28d3a3e"),
        .target(name: "RoktWidget",
                dependencies: [
                    .target(name: "Rokt_Widget")
                ],
                path: "Source",
                resources: [.copy("PrivacyInfo.xcprivacy")])
    ]
)