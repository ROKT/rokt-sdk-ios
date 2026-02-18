// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Rokt-Widget",
            type: .dynamic,
            targets: ["Rokt_Widget"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ROKT/rokt-ux-helper-ios.git", exact: "0.8.0"),
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        .target(
            name: "Rokt_Widget",
            dependencies: [
                .product(name: "RoktUXHelper", package: "rokt-ux-helper-ios")
            ],
            path: "Sources/Rokt_Widget",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "Rokt_WidgetTests",
            dependencies: ["Rokt_Widget", "Mocker"],
            path: "Tests/Rokt_WidgetTests",
            resources: [
                .process("Resource")
            ]
        )
    ]
)
