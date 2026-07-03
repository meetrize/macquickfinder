import XCTest
@testable import Explorer

final class GitWorkspaceReaderTests: XCTestCase {
    func testLoadSnapshotInCurrentRepository() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path

        let snapshot = try GitWorkspaceReader.loadSnapshot(cwd: repoRoot)
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.repoRoot, repoRoot)
        XCTAssertFalse(snapshot?.currentBranch?.isEmpty ?? true)
        XCTAssertNotNil(snapshot?.lastRefreshedAt)
    }

    func testLoadSnapshotReturnsNilOutsideRepository() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-git-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let snapshot = try GitWorkspaceReader.loadSnapshot(cwd: root.path)
        XCTAssertNil(snapshot)
    }

    func testLoadSnapshotUsesInjectedCLI() throws {
        let calls = GitCallLog()
        let cli = GitCLI(runProcess: { _, arguments, workingDirectory, _ in
            calls.record(arguments: arguments, cwd: workingDirectory)
            let joined = arguments.joined(separator: " ")
            let stdout: Data
            switch joined {
            case "branch --show-current":
                stdout = Data("feature/git".utf8)
            case "status --porcelain=v1 -z":
                stdout = Data(" M tracked.txt\0".utf8)
            case "rev-parse --abbrev-ref --symbolic-full-name @{u}":
                stdout = Data("origin/feature/git".utf8)
            case "rev-list --left-right --count HEAD...@{u}":
                stdout = Data("1\t2".utf8)
            default:
                XCTFail("Unexpected git arguments: \(joined)")
                stdout = Data()
            }
            return GitProcessResult(stdout: stdout, stderr: Data(), terminationStatus: 0)
        })

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path

        let snapshot = try GitWorkspaceReader.loadSnapshot(cwd: root, cli: cli)
        XCTAssertEqual(snapshot?.currentBranch, "feature/git")
        XCTAssertEqual(snapshot?.changeCount, 1)
        XCTAssertEqual(snapshot?.behindCount, 1)
        XCTAssertEqual(snapshot?.aheadCount, 2)
        XCTAssertTrue(snapshot?.hasUpstream ?? false)
        XCTAssertTrue(calls.arguments.contains(["status", "--porcelain=v1", "-z"]))
    }
}

private final class GitCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var arguments: [[String]] = []
    private(set) var workingDirectories: [String] = []

    func record(arguments: [String], cwd: String) {
        lock.lock()
        self.arguments.append(arguments)
        workingDirectories.append(cwd)
        lock.unlock()
    }
}
