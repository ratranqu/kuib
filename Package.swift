// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "kuib",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "kuib", targets: ["App"]),
    ],
    dependencies: [
        // Web server
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.5.0"),

        // HTML rendering
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.6.0"),
        .package(url: "https://github.com/elementary-swift/elementary-htmx.git", from: "0.4.0"),
        .package(url: "https://github.com/hummingbird-community/hummingbird-elementary.git", from: "0.4.0"),

        // Kubernetes client
        .package(url: "https://github.com/swiftkube/client.git", from: "0.25.0"),

        // Database
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),

        // Logging & Metrics
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Main executable
        .executableTarget(
            name: "App",
            dependencies: [
                "Server",
                "Pages",
                "K8s",
                "Database",
                "Alerts",
                "Models",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/App"
        ),

        // HTTP server, routes, middleware
        .target(
            name: "Server",
            dependencies: [
                "Pages",
                "K8s",
                "Database",
                "Alerts",
                "Models",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdElementary", package: "hummingbird-elementary"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Server"
        ),

        // Elementary HTML pages and components
        .target(
            name: "Pages",
            dependencies: [
                "Components",
                "Database",
                "Models",
                .product(name: "Elementary", package: "elementary"),
                .product(name: "ElementaryHTMX", package: "elementary-htmx"),
                .product(name: "ElementaryHTMXSSE", package: "elementary-htmx"),
            ],
            path: "Sources/Pages"
        ),

        // Reusable HTML components
        .target(
            name: "Components",
            dependencies: [
                "Models",
                .product(name: "Elementary", package: "elementary"),
                .product(name: "ElementaryHTMX", package: "elementary-htmx"),
                .product(name: "ElementaryHTMXSSE", package: "elementary-htmx"),
            ],
            path: "Sources/Components"
        ),

        // Kubernetes client wrapper, watchers, cache
        .target(
            name: "K8s",
            dependencies: [
                "Models",
                .product(name: "SwiftkubeClient", package: "client"),
                .product(name: "SwiftkubeModel", package: "client"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/K8s"
        ),

        // PostgreSQL models, migrations, queries
        .target(
            name: "Database",
            dependencies: [
                "Models",
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Database"
        ),

        // Alert engine and webhook dispatcher
        .target(
            name: "Alerts",
            dependencies: [
                "Models",
                "K8s",
                "Database",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Alerts"
        ),

        // Shared data models
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"
        ),

        // Unit tests
        .testTarget(
            name: "KuibTests",
            dependencies: [
                "App",
                "Server",
                "Pages",
                "Components",
                "K8s",
                "Database",
                "Alerts",
                "Models",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            path: "Tests/KuibTests"
        ),

        // Integration tests
        .testTarget(
            name: "KuibIntegrationTests",
            dependencies: [
                "App",
                "Server",
                "K8s",
                "Database",
                "Models",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            path: "Tests/KuibIntegrationTests"
        ),
    ]
)
