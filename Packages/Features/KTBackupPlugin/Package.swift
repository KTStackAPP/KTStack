// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTBackupPlugin",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KTBackupPlugin", targets: ["KTBackupPlugin"])
    ],
    dependencies: [
        .package(path: "../../Core/KTStackCore"),
        .package(path: "../../Contracts/KTPlatformContracts"),
        .package(path: "../../Plugin/KTPluginKit")
    ],
    targets: [
        .target(
            name: "KTBackupPlugin",
            dependencies: [
                .product(name: "KTStackCore", package: "KTStackCore"),
                .product(name: "KTPlatformContracts", package: "KTPlatformContracts"),
                .product(name: "KTPluginKit", package: "KTPluginKit")
            ]
        ),
        .testTarget(
            name: "KTBackupPluginTests",
            dependencies: ["KTBackupPlugin"]
        )
    ]
)

for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + [.unsafeFlags(["-strict-concurrency=targeted"])]
}
