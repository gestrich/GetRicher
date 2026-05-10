// swift-tools-version: 6.0

import PackageDescription

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", "2.0.0"..<"3.0.0"),
    .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.5.0"),
    .package(url: "https://github.com/soto-project/soto.git", from: "7.10.0"),
]

var products: [Product] = [
    .library(name: "CoreService", targets: ["CoreService"]),
    .library(name: "FinanceCoreSDK", targets: ["FinanceCoreSDK"]),
    .library(name: "LunchMoneySDK", targets: ["LunchMoneySDK"]),
    .library(name: "NotificationService", targets: ["NotificationService"]),
    .library(name: "ReportingService", targets: ["ReportingService"]),
    .library(name: "SecretsService", targets: ["SecretsService"]),
    .library(name: "Uniflow", targets: ["Uniflow"]),
    .library(name: "ClientService", targets: ["ClientService"]),
    .executable(name: "LambdaApp", targets: ["LambdaApp"]),
]

var targets: [Target] = [
    // SDKs Layer
    .target(
        name: "FinanceCoreSDK",
        dependencies: [
            .product(name: "Crypto", package: "swift-crypto"),
        ],
        path: "Sources/sdks/FinanceCoreSDK"
    ),
    .target(
        name: "LunchMoneySDK",
        dependencies: [
            .target(name: "FinanceCoreSDK")
        ],
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
        name: "ClientService",
        dependencies: [
            .target(name: "FinanceCoreSDK"),
        ],
        path: "Sources/services/ClientService"
    ),
    .target(
        name: "NotificationService",
        dependencies: [
            .target(name: "FinanceCoreSDK"),
            .product(name: "SotoDynamoDB", package: "soto"),
            .product(name: "SotoSNS", package: "soto"),
        ],
        path: "Sources/services/NotificationService"
    ),
    .target(
        name: "ReportingService",
        dependencies: ["FinanceCoreSDK"],
        path: "Sources/services/ReportingService"
    ),
    .target(
        name: "SecretsService",
        dependencies: [
            .product(name: "SotoSecretsManager", package: "soto"),
        ],
        path: "Sources/services/SecretsService"
    ),
    // Test Targets (unconditional — pure Linux-safe targets)
    .testTarget(
        name: "ReportingServiceTests",
        dependencies: ["ReportingService", "FinanceCoreSDK"],
        path: "Tests/ReportingServiceTests"
    ),
    .testTarget(
        name: "LunchMoneySDKTests",
        dependencies: ["LunchMoneySDK"],
        path: "Tests/LunchMoneySDKTests"
    ),
    .testTarget(
        name: "NotificationServiceTests",
        dependencies: ["NotificationService", "FinanceCoreSDK"],
        path: "Tests/NotificationServiceTests"
    ),
    // Apps Layer
    .executableTarget(
        name: "LambdaApp",
        dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "SotoCloudWatchLogs", package: "soto"),
            .target(name: "ClientService"),
            .target(name: "FinanceCoreSDK"),
            .target(name: "LunchMoneySDK"),
            .target(name: "NotificationService"),
            .target(name: "ReportingService"),
            .target(name: "SecretsService"),
        ],
        path: "Sources/apps/LambdaApp"
    ),
]

#if os(macOS) || os(iOS)
dependencies.append(contentsOf: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    .package(url: "https://github.com/swift-otel/swift-otel.git", from: "1.0.0"),
    .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
])
products.append(contentsOf: [
    .library(name: "LoggingSDK", targets: ["LoggingSDK"]),
    .library(name: "LogsFeature", targets: ["LogsFeature"]),
    .library(name: "KeychainSDK", targets: ["KeychainSDK"]),
    .library(name: "PersistenceService", targets: ["PersistenceService"]),
    .library(name: "SyncService", targets: ["SyncService"]),
    .executable(name: "CLIApp", targets: ["CLIApp"]),
])
targets.append(contentsOf: [
    .target(
        name: "LoggingSDK",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "OTel", package: "swift-otel"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        ],
        path: "Sources/sdks/LoggingSDK"
    ),
    .target(
        name: "LogsFeature",
        dependencies: ["LoggingSDK", "Uniflow"],
        path: "Sources/features/LogsFeature"
    ),
    .target(
        name: "KeychainSDK",
        path: "Sources/sdks/KeychainSDK"
    ),
    .target(
        name: "PersistenceService",
        dependencies: ["FinanceCoreSDK"],
        path: "Sources/services/PersistenceService"
    ),
    .target(
        name: "SyncService",
        dependencies: ["ClientService", "FinanceCoreSDK", "PersistenceService", "KeychainSDK"],
        path: "Sources/services/SyncService"
    ),
    .executableTarget(
        name: "CLIApp",
        dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .target(name: "ClientService"),
        ],
        path: "Sources/apps/CLIApp",
        swiftSettings: [
            .unsafeFlags(["-parse-as-library"])
        ]
    ),
])
#endif

let package = Package(
    name: "FinancePackage",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: products,
    dependencies: dependencies,
    targets: targets
)
