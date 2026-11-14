// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ManicSaveSync",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [.library(name: "SaveSyncCore", targets: ["SaveSyncCore"])],
    targets: [
        .target(name: "SaveSyncCore", path: "ManicEmu/ManicEmu/Sources/Tools/Sync/Shared"),
        .testTarget(name: "SaveSyncCoreTests", dependencies: ["SaveSyncCore"], path: "Tests/SaveSyncCoreTests")
    ]
)
