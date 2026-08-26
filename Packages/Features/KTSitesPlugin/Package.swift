// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTSitesPlugin",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KTSitesPlugin", targets: ["KTSitesPlugin"])
    ],
    dependencies: [
        .package(path: "../../Core/KTStackCore"),
        .package(path: "../../Contracts/KTPlatformContracts"),
        .package(path: "../../Plugin/KTPluginKit")
    ],
    targets: [
        .target(
            name: "KTSitesPlugin",
            dependencies: [
                .product(name: "KTStackCore", package: "KTStackCore"),
                .product(name: "KTPlatformContracts", package: "KTPlatformContracts"),
                .product(name: "KTPluginKit", package: "KTPluginKit")
            ]
        ),
        .testTarget(
            name: "KTSitesPluginTests",
            dependencies: ["KTSitesPlugin"]
        )
    ]
)
