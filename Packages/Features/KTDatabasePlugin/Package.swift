// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTDatabasePlugin",
    platforms: [.macOS(.v13)],
    products: [
        // Automatic: only the app links it. The four pure-Swift drivers link statically into the
        // app executable (they used to sit in the framework), so the bundle stays notarize-clean.
        .library(name: "KTDatabasePlugin", targets: ["KTDatabasePlugin"])
    ],
    dependencies: [
        .package(path: "../../Core/KTStackCore"),
        .package(path: "../../Contracts/KTPlatformContracts"),
        .package(path: "../../Plugin/KTPluginKit"),
        // Driver versions pinned to match the old project.yml resolve; swift-nio/ssl/log pinned to
        // the versions those drivers already resolve to (see Package.resolved).
        .package(url: "https://github.com/vapor/mysql-nio", from: "1.9.0"),
        .package(url: "https://github.com/vapor/postgres-nio", from: "1.21.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/orlandos-nl/MongoKitten", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.101.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.37.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.13.2")
    ],
    targets: [
        .target(
            name: "KTDatabasePlugin",
            dependencies: [
                .product(name: "KTStackCore", package: "KTStackCore"),
                .product(name: "KTPlatformContracts", package: "KTPlatformContracts"),
                .product(name: "KTPluginKit", package: "KTPluginKit"),
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "MongoKitten", package: "MongoKitten"),
                .product(name: "MongoCore", package: "MongoKitten"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "KTDatabasePluginTests",
            dependencies: [
                "KTDatabasePlugin",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "NIOCore", package: "swift-nio")
            ]
        )
    ]
)
