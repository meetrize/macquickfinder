import XCTest
@testable import Explorer

final class GitRepositoryDetectorTests: XCTestCase {
    private var tempRoots: [URL] = []

    override func tearDown() {
        for root in tempRoots {
            try? FileManager.default.removeItem(at: root)
        }
        tempRoots.removeAll()
        super.tearDown()
    }

    func testFindRepoRootFromNestedDirectory() throws {
        let root = try makeTempRepo()
        let nested = root.appendingPathComponent("Sources/Explorer", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        XCTAssertEqual(
            GitRepositoryDetector.findRepoRoot(from: nested.path),
            root.path
        )
    }

    func testFindRepoRootFromFilePathUsesParentDirectory() throws {
        let root = try makeTempRepo()
        let file = root.appendingPathComponent("README.md")
        try Data("demo".utf8).write(to: file)

        XCTAssertEqual(
            GitRepositoryDetector.findRepoRoot(from: file.path),
            root.path
        )
    }

    func testFindRepoRootReturnsNilOutsideRepository() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-git-detector-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        tempRoots.append(root)

        XCTAssertNil(GitRepositoryDetector.findRepoRoot(from: root.path))
    }

    func testFindRepoRootInCurrentProject() {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path

        XCTAssertEqual(
            GitRepositoryDetector.findRepoRoot(from: repoRoot),
            repoRoot
        )
    }

    private func makeTempRepo() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-git-detector-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        tempRoots.append(root)
        return root
    }
}
