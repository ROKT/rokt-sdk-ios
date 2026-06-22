// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Note: 5.5 is the minimum that supports .iOS(.v15) in PackageDescription.

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Rokt-Widget",
            targets: ["Rokt_Widget"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt_Widget",
            url: "https://github.com/ROKT/rokt-sdk-ios/releases/download/4.16.6/Rokt_Widget.xcframework.zip",
            checksum: "d659ed2dd435a47f0e588954e286fa6d97d8faa29c273b703fc8c6223b00a5cd")
    ]
)