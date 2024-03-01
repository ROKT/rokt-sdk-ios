// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "Rokt-Widget",
            targets: ["Rokt_WidgetTargets"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Rokt_Widget",
                      url: "https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/3.15.8/Rokt_Widget.xcframework.zip",
                      checksum: "13312a7197e513a9838cc4167381cc1fca9735a108c7727c3dc34529692b229f"),
        .target(name: "Rokt_WidgetTargets",
                dependencies: [
                    .target(name: "Rokt_Widget")
                ],
                path: "Source",
                resources: [.copy("PrivacyInfo.xcprivacy")])
    ]
)
