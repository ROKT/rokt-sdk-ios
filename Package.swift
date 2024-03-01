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
                      url: "https://apps.rokt.com/msdk/ios/4.1.0/Rokt_Widget.xcframework.zip",
                      checksum: "3eab30986bd748aebdf2edb99ff9236bc97247cbc15c865ed74725197770c9a8"),
        .target(name: "RoktWidget",
                dependencies: [
                    .target(name: "Rokt_Widget")
                ],
                path: "Source",
                resources: [.copy("PrivacyInfo.xcprivacy")])
    ]
)