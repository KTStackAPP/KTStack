// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTStackCore",
    platforms: [.macOS(.v13)],
    products: [
        // Dynamic for the framework/app (embedded once in the app bundle).
        .library(name: "KTStackCore", type: .dynamic, targets: ["KTStackCore"]),
        // Static for the two standalone tool targets: they must stay self-contained
        // since ktstack-resolve is copied out of the bundle into the shell shim dir.
        .library(name: "KTStackCoreStatic", type: .static, targets: ["KTStackCore"])
    ],
    targets: [
        .target(name: "KTStackCore")
    ]
)
