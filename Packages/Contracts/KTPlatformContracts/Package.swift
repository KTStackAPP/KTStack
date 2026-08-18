// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTPlatformContracts",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KTPlatformContracts", targets: ["KTPlatformContracts"])
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
