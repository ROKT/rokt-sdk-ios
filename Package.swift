// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rokt-Widget",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Rokt-Widget",
            targets: ["Rokt_Widget"]),
        .library(
            name: "Rokt-Stripe-Payment-Kit",
            targets: ["Rokt-Stripe-Payment-Kit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stripe/stripe-ios", from: "24.25.0")
    ],
    targets: [
        .binaryTarget(
            name: "Rokt_Widget",
            url: "https://github.com/rokt/rokt-sdk-ios/raw/UTYP-589-Post-Purchase-Upsells/Rokt_Widget.xcframework.zip",
            checksum: "d8236e1db0c9d33da9fa5259ddce4899a2487ec8e4997d7988158d8e87cb6926"),
        .target(
            name: "Rokt-Stripe-Payment-Kit",
            dependencies: [
                "Rokt_Widget",
                .product(name: "Stripe", package: "stripe-ios")
            ],
            path: "Rokt-Stripe-Payment-Kit",
            exclude: ["Rokt_Stripe_Payment_KitTests"]),
        .testTarget(
            name: "Rokt-Stripe-Payment-KitTests",
            dependencies: ["Rokt-Stripe-Payment-Kit", "Rokt_Widget"],
            path: "Rokt-Stripe-Payment-Kit/Rokt_Stripe_Payment_KitTests")
    ]
)
