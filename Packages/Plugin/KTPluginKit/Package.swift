// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTPluginKit",
    platforms: [.macOS(.v13)],
    products: [
        // Dynamic for type identity: the app embeds it once and every feature
        // package (M04+) links the same copy, so capability casts and token
        // types stay one type across modules (same layout as KTStackCore).
        .library(name: "KTPluginKit", type: .dynamic, targets: ["KTPluginKit"])
    ],
    dependencies: [
        .package(path: "../../Core/KTStackCore")
    ],
    targets: [
        .target(
            name: "KTPluginKit",
            dependencies: [.product(name: "KTStackCore", package: "KTStackCore")]
        )
    ]
)
