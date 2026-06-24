// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Explorer",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Explorer", targets: ["Explorer"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FileList",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Explorer",
            dependencies: ["FileList"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FileListTests",
            dependencies: ["FileList"]),
        .testTarget(
            name: "ExplorerTests",
            dependencies: ["FileList", "Explorer"])
    ]
)
