// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    platforms: [.iOS(.v9)],
    products: [
        .library(
            name: "Rokt-Widget",
            targets: ["Rokt_Widget"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt_Widget",
                      url: "https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/3.5.0-alpha.2487/Rokt_Widget.xcframework.zip",
                      checksum: "5c3ba025b886c4a8c024796b72caa4bea0b3e68548cd8fddafa9ba3fe7aee4de")
    ]
)
