// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rokt_Widget",
    platforms: [.iOS(.v9)],
    products: [
        .library(
            name: "Rokt_Widget",
            targets: ["Rokt-Widget"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt-Widget",
                      url: "https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/3.5.0-alpha.2474/Rokt_Widget.xcframework.zip",
                      checksum: "b9bf942d1c4723ef7edb570b8b24c0f17f0fbd69875d01dd0d2d27a76846fa09")
    ]
)
