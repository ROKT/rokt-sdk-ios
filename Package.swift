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
                      url: "https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/4.1.0-beta.6/Rokt_Widget.xcframework.zip",
                      checksum: "43bc9abee0a78a4efee728de25b941d2f7db32e7443bf5e1b2ef14f7f9435cb5")
    ]
)