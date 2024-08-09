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
                      url: "https://apps.rokt.com/msdk/ios/4.5.0/Rokt_Widget.xcframework.zip",
                      checksum: "c6b7a8de8a6ac9c559c075629edf85d4e1a81f13dba61fe75a808a981f744064")
    ]
)