// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTRuntimesPlugin",
    platforms: [.macOS(.v13)],
    products: [
        // Automatic: only the app links it. Shares no type with a sibling module beyond the
        // dynamic deps below, so it needs no dynamic product of its own.
        .library(name: "KTRuntimesPlugin", targets: ["KTRuntimesPlugin"])
    ],
    dependencies: [
        .package(path: "../../Core/KTStackCore"),
        .package(path: "../../Contracts/KTPlatformContracts"),
        .package(path: "../../Plugin/KTPluginKit")
    ],
    targets: [
        .target(
            name: "KTRuntimesPlugin",
            dependencies: [
                .product(name: "KTStackCore", package: "KTStackCore"),
                .product(name: "KTPlatformContracts", package: "KTPlatformContracts"),
                .product(name: "KTPluginKit", package: "KTPluginKit")
            ]
        ),
        .testTarget(
            name: "KTRuntimesPluginTests",
            dependencies: ["KTRuntimesPlugin"]
        )
    ]
)
