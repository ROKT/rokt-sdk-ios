// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RoktUXHelper",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "RoktUXHelper",
            targets: ["RoktUXHelper"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ROKT/dcui-swift-schema.git", exact: "2.7.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", exact: "0.10.3"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", exact: "1.19.2")
    ],
    targets: [
        .target(
            name: "RoktUXHelper",
            dependencies: [.product(name: "DcuiSchema", package: "dcui-swift-schema")],
            resources: [.process("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "RoktUXHelperTests",
            dependencies: ["RoktUXHelper",
                           .product(name: "ViewInspector", package: "ViewInspector"),
                           .product(name: "DcuiSchema", package: "dcui-swift-schema"),
                           .product(name: "SnapshotTesting", package: "swift-snapshot-testing")],
            path: "Tests/RoktUXHelperTests",
            resources: [
                .process("Supporting Files")
            ]
        )
    ]
)
