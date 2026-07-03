// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Explorer",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Explorer", targets: ["Explorer"]),
        .executable(name: "DocumentOpener", targets: ["DocumentOpener"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FileList",
            dependencies: [],
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-O"], .when(configuration: .release))
            ]
        ),
        .executableTarget(
            name: "Explorer",
            dependencies: ["FileList"],
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-O"], .when(configuration: .release))
            ]
        ),
        .executableTarget(
            name: "DocumentOpener",
            dependencies: []
        ),
        .testTarget(
            name: "FileListTests",
            dependencies: ["FileList"]),
        .testTarget(
            name: "ExplorerTests",
            dependencies: ["FileList", "Explorer"]),
        .testTarget(
            name: "ExplorerGitTests",
            dependencies: ["Explorer"])
    ]
)
