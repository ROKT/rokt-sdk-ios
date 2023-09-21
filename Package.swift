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
                      url: "https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/4.0.0-beta.1/Rokt_Widget.xcframework.zip",
                      checksum: "384955cc22bfc0eeeb4ff773dd06fe8abf9e91174f45877b139470ba2f080fb9")
    ]
)
