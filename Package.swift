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
                      url: "https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/3.6.3/Rokt_Widget.xcframework.zip",
                      checksum: "f937d9cf3be6da586bf1e4a6c0ea17402c5e0f1d3f2ae4ccdb954429a200a13c")
    ]
)
