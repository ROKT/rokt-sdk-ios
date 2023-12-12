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
                      url: "https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/4.1.0-beta.3/Rokt_Widget.xcframework.zip",
                      checksum: "3c3afbed558650772f87c07be5e4520907c9ef1d48aba2783275833b30be7508")
    ]
)
