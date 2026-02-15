// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FinancePackage",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "CoreService", targets: ["CoreService"]),
        .library(name: "KeychainSDK", targets: ["KeychainSDK"]),
        .library(name: "LunchMoneySDK", targets: ["LunchMoneySDK"]),
        .library(name: "TransactionFeature", targets: ["TransactionFeature"]),
        .library(name: "Uniflow", targets: ["Uniflow"]),
    ],
    targets: [
        // SDKs Layer
        .target(
            name: "Uniflow",
            path: "Sources/sdks/Uniflow"
        ),
        .target(
            name: "LunchMoneySDK",
            path: "Sources/sdks/LunchMoneySDK"
        ),
        .target(
            name: "KeychainSDK",
            path: "Sources/sdks/KeychainSDK"
        ),
        // Services Layer
        .target(
            name: "CoreService",
            path: "Sources/services/CoreService"
        ),
        // Features Layer
        .target(
            name: "TransactionFeature",
            dependencies: ["CoreService", "KeychainSDK", "LunchMoneySDK", "Uniflow"],
            path: "Sources/features/TransactionFeature"
        ),
    ]
)
