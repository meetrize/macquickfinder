import XCTest
@testable import Explorer

final class ApplicationsDirectoryMergeTests: XCTestCase {
    func testSupplementalPathsForApplications() {
        let paths = ApplicationsDirectoryMerge.supplementalPaths(
            for: "/Applications",
            fileExists: { $0 == "/System/Applications" }
        )
        XCTAssertEqual(paths, ["/System/Applications"])
    }

    func testSupplementalPathsForUtilities() {
        let paths = ApplicationsDirectoryMerge.supplementalPaths(
            for: "/Applications/Utilities",
            fileExists: { $0 == "/System/Applications/Utilities" }
        )
        XCTAssertEqual(paths, ["/System/Applications/Utilities"])
    }

    func testSupplementalPathsIgnoresSystemApplicationsAlone() {
        let paths = ApplicationsDirectoryMerge.supplementalPaths(
            for: "/System/Applications",
            fileExists: { _ in true }
        )
        XCTAssertTrue(paths.isEmpty)
    }

    func testSupplementalPathsWhenSystemFolderMissing() {
        let paths = ApplicationsDirectoryMerge.supplementalPaths(
            for: "/Applications",
            fileExists: { _ in false }
        )
        XCTAssertTrue(paths.isEmpty)
    }

    func testSupplementalPathsNormalizesTrailingSlash() {
        let paths = ApplicationsDirectoryMerge.supplementalPaths(
            for: "/Applications/",
            fileExists: { $0 == "/System/Applications" }
        )
        XCTAssertEqual(paths, ["/System/Applications"])
    }

    func testMergeURLsPrefersPrimaryOnNameCollision() {
        let primary = [
            URL(fileURLWithPath: "/Applications/Safari.app"),
            URL(fileURLWithPath: "/Applications/Cursor.app"),
        ]
        let system = [
            URL(fileURLWithPath: "/System/Applications/Safari.app"),
            URL(fileURLWithPath: "/System/Applications/Calculator.app"),
        ]
        let merged = ApplicationsDirectoryMerge.mergeURLs(
            primary: primary,
            supplementalGroups: [system]
        )
        XCTAssertEqual(
            merged.map(\.path),
            [
                "/Applications/Safari.app",
                "/Applications/Cursor.app",
                "/System/Applications/Calculator.app",
            ]
        )
    }

    func testLiveApplicationsListingIncludesSystemApps() throws {
        // 仅在真实 macOS 布局存在时断言，避免沙盒/精简环境误失败。
        let systemApps = "/System/Applications"
        guard FileManager.default.fileExists(atPath: systemApps) else {
            throw XCTSkip("/System/Applications 不存在，跳过实机合并验证")
        }

        let items = try DirectoryListingLoader.loadFileItems(
            at: "/Applications",
            showHiddenFiles: false
        )
        let fromSystem = items.filter { $0.url.path.hasPrefix(systemApps + "/") }
        XCTAssertFalse(fromSystem.isEmpty, "合并后应包含来自 \(systemApps) 的应用")
        XCTAssertTrue(
            fromSystem.contains { $0.name == "Calculator.app" },
            "应能看到系统自带的 Calculator.app"
        )

        // 同名优先用户侧：若双方都有 Safari，条目路径应落在 /Applications。
        if let safari = items.first(where: { $0.name == "Safari.app" }),
           FileManager.default.fileExists(atPath: "/Applications/Safari.app") {
            XCTAssertEqual(safari.url.path, "/Applications/Safari.app")
        }
    }
}
