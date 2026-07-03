import XCTest
@testable import Explorer

@MainActor
final class GitStatusStoreTests: XCTestCase {
    func testRefreshPublishesSnapshot() async throws {
        let cli = GitCLI(runProcess: { _, arguments, _, _ in
            let joined = arguments.joined(separator: " ")
            let stdout: Data
            switch joined {
            case "branch --show-current":
                stdout = Data("main".utf8)
            case "status --porcelain=v1 -z":
                stdout = Data()
            case "rev-parse --abbrev-ref --symbolic-full-name @{u}":
                stdout = Data("origin/main".utf8)
            case "rev-list --left-right --count HEAD...@{u}":
                stdout = Data("0\t0".utf8)
            default:
                if joined.hasPrefix("log -") {
                    stdout = Data()
                } else {
                    stdout = Data()
                }
            }
            return GitProcessResult(stdout: stdout, stderr: Data(), terminationStatus: 0)
        })

        let store = GitStatusStore(cli: cli)
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path

        await store.refresh(cwd: repoRoot)

        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.snapshot?.repoRoot, repoRoot)
        XCTAssertEqual(store.snapshot?.workspacePhase, .cleanSynced)
    }

    func testRefreshPublishesError() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-git-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let cli = GitCLI(runProcess: { _, _, _, _ in
            throw GitCLIError.nonZeroExit(code: 128, stderr: "fatal: not a git repository")
        })

        let store = GitStatusStore(cli: cli)
        await store.refresh(cwd: root.path)

        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.lastError, "fatal: not a git repository")
    }

    @MainActor
    func testClearPendingChangesRemovesEntries() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-git-clear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let cli = GitCLI(runProcess: { _, arguments, _, _ in
            let joined = arguments.joined(separator: " ")
            let stdout: Data
            switch joined {
            case "branch --show-current":
                stdout = Data("main".utf8)
            case "status --porcelain=v1 -z":
                stdout = Data(" M a.swift\0".utf8)
            case "rev-parse --abbrev-ref --symbolic-full-name @{u}":
                stdout = Data("origin/main".utf8)
            case "rev-list --left-right --count HEAD...@{u}":
                stdout = Data("0\t0".utf8)
            default:
                stdout = joined.hasPrefix("log -") ? Data() : Data()
            }
            return GitProcessResult(stdout: stdout, stderr: Data(), terminationStatus: 0)
        })

        let store = GitStatusStore(cli: cli)
        await store.refresh(cwd: root.path)
        XCTAssertEqual(store.snapshot?.changeCount, 1)

        store.clearPendingChanges(forRepoRoot: root.path)
        XCTAssertEqual(store.snapshot?.changeCount, 0)
    }

    func testClearResetsState() async {
        let store = GitStatusStore(cli: .live)
        await store.refresh(cwd: "/")
        store.clear()
        XCTAssertNil(store.snapshot)
        XCTAssertNil(store.lastError)
        XCTAssertFalse(store.isRefreshing)
    }
}
