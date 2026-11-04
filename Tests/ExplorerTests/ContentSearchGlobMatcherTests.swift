import XCTest
@testable import Explorer

final class ContentSearchGlobMatcherTests: XCTestCase {
    func testSwiftExtensionGlobMatchesFileName() {
        XCTAssertTrue(
            ContentSearchGlobMatcher.matches(
                relativePath: "Sources/App.swift",
                fileName: "App.swift",
                includePatterns: ["*.swift"],
                excludePatterns: []
            )
        )
        XCTAssertFalse(
            ContentSearchGlobMatcher.matches(
                relativePath: "README.md",
                fileName: "README.md",
                includePatterns: ["*.swift"],
                excludePatterns: []
            )
        )
    }

    func testExcludeNodeModules() {
        XCTAssertFalse(
            ContentSearchGlobMatcher.matches(
                relativePath: "node_modules/pkg/index.js",
                fileName: "index.js",
                includePatterns: [],
                excludePatterns: ["node_modules/**"]
            )
        )
    }

    func testPathPatternMatchesRelativePath() {
        XCTAssertTrue(
            ContentSearchGlobMatcher.matches(
                relativePath: "Tests/Unit/AppTests.swift",
                fileName: "AppTests.swift",
                includePatterns: ["**/Tests/**"],
                excludePatterns: []
            )
        )
        XCTAssertFalse(
            ContentSearchGlobMatcher.matches(
                relativePath: "Sources/App.swift",
                fileName: "App.swift",
                includePatterns: ["**/Tests/**"],
                excludePatterns: []
            )
        )
    }

    func testCompiledGlobPrunesExcludedDirectories() {
        let glob = ContentSearchGlobMatcher.Compiled(
            includePatterns: [],
            excludePatterns: ["node_modules/**", "**/DerivedData/**"]
        )

        XCTAssertTrue(glob.excludesDirectory(relativePath: "node_modules"))
        XCTAssertTrue(glob.excludesDirectory(relativePath: "Sources/DerivedData"))
        XCTAssertFalse(glob.excludesDirectory(relativePath: "Sources/App"))
    }

    func testExcludeWinsOverInclude() {
        XCTAssertFalse(
            ContentSearchGlobMatcher.matches(
                relativePath: "node_modules/lib/foo.swift",
                fileName: "foo.swift",
                includePatterns: ["*.swift"],
                excludePatterns: ["node_modules/**"]
            )
        )
    }
}
