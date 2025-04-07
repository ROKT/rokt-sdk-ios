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
                      url: "https://apps.rokt.com/msdk/ios/4.9.1/Rokt_Widget.xcframework.zip",
                      checksum: "d7a5af0d4abb227f21558cd445d17602ccbb48bea6abdb1889765cb2e8e09744")
    ]
)