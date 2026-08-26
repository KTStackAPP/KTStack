// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTServicesPlugin",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KTServicesPlugin", targets: ["KTServicesPlugin"])
    ],
    dependencies: [
        .package(path: "../../Contracts/KTPlatformContracts"),
        .package(path: "../../Plugin/KTPluginKit")
    ],
    targets: [
        .target(
            name: "KTServicesPlugin",
            dependencies: [
                .product(name: "KTPlatformContracts", package: "KTPlatformContracts"),
                .product(name: "KTPluginKit", package: "KTPluginKit")
            ]
        ),
        .testTarget(
            name: "KTServicesPluginTests",
            dependencies: ["KTServicesPlugin"]
        )
    ]
)
