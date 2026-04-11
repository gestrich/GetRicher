// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FinancePackage",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "CoreService", targets: ["CoreService"]),
        .library(name: "LoggingSDK", targets: ["LoggingSDK"]),
        .library(name: "LogsFeature", targets: ["LogsFeature"]),
        .library(name: "PersistenceService", targets: ["PersistenceService"]),
        .library(name: "SyncService", targets: ["SyncService"]),
        .library(name: "KeychainSDK", targets: ["KeychainSDK"]),
        .library(name: "LunchMoneySDK", targets: ["LunchMoneySDK"]),
        .library(name: "Uniflow", targets: ["Uniflow"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        // SDKs Layer
        .target(
            name: "KeychainSDK",
            path: "Sources/sdks/KeychainSDK"
        ),
        .target(
            name: "LoggingSDK",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/sdks/LoggingSDK"
        ),
        .target(
            name: "LunchMoneySDK",
            path: "Sources/sdks/LunchMoneySDK"
        ),
        .target(
            name: "Uniflow",
            path: "Sources/sdks/Uniflow"
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
            name: "LogsFeature",
            dependencies: ["LoggingSDK", "Uniflow"],
            path: "Sources/features/LogsFeature"
        ),
    ]
)
