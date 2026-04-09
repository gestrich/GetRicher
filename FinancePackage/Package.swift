// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FinancePackage",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "CoreService", targets: ["CoreService"]),
        .library(name: "PersistenceService", targets: ["PersistenceService"]),
        .library(name: "SyncService", targets: ["SyncService"]),
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
        .target(
            name: "PersistenceService",
            path: "Sources/services/PersistenceService"
        ),
        .target(
            name: "SyncService",
            dependencies: ["LunchMoneySDK", "PersistenceService", "KeychainSDK"],
            path: "Sources/services/SyncService"
        ),
        // Features Layer
        .target(
            name: "TransactionFeature",
            dependencies: ["PersistenceService", "SyncService"],
            path: "Sources/features/TransactionFeature"
        ),
    ]
)
