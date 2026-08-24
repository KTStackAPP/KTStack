// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTPlatformContracts",
    platforms: [.macOS(.v13)],
    products: [
        // Dynamic for type identity: the app embeds it once, KTStackKit and every feature
        // package (M04+) link the same copy, so protocol conformances stay one type across the
        // framework and the app binary and capability casts over the plugin boundary hold
        // (same layout as KTStackCore / KTPluginKit).
        .library(name: "KTPlatformContracts", type: .dynamic, targets: ["KTPlatformContracts"])
    ],
    dependencies: [
        .package(path: "../../Core/KTStackCore")
    ],
    targets: [
        .target(
            name: "KTPlatformContracts",
            dependencies: [.product(name: "KTStackCore", package: "KTStackCore")]
        )
    ]
)
