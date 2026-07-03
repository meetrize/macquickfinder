import XCTest
@testable import Explorer

final class GitWorkspacePhaseTests: XCTestCase {
    func testCleanSyncedWhenNoChangesAndNoAhead() {
        let snapshot = makeSnapshot(entries: [], ahead: 0, behind: 0)
        XCTAssertEqual(snapshot.workspacePhase, .cleanSynced)
    }

    func testDirtyWhenPorcelainHasEntries() {
        let snapshot = makeSnapshot(
            entries: [GitPorcelainEntry(status: .modified, path: "a.swift")],
            ahead: 2,
            behind: 3
        )
        XCTAssertEqual(snapshot.workspacePhase, .dirty)
    }

    func testBehindOrConflictWhenOnlyBehind() {
        let snapshot = makeSnapshot(entries: [], ahead: 0, behind: 2)
        XCTAssertEqual(snapshot.workspacePhase, .behindOrConflict)
    }

    func testAheadOnlyWhenNoChangesButAhead() {
        let snapshot = makeSnapshot(entries: [], ahead: 3, behind: 0)
        XCTAssertEqual(snapshot.workspacePhase, .aheadOnly)
    }

    func testConflictTakesPriorityOverDirty() {
        let snapshot = makeSnapshot(
            entries: [
                GitPorcelainEntry(status: .conflict, path: "conflict.swift"),
                GitPorcelainEntry(status: .modified, path: "other.swift"),
            ],
            ahead: 0,
            behind: 0
        )
        XCTAssertEqual(snapshot.workspacePhase, .behindOrConflict)
        XCTAssertEqual(snapshot.conflictedPaths, ["conflict.swift"])
    }

    private func makeSnapshot(
        entries: [GitPorcelainEntry],
        ahead: Int,
        behind: Int
    ) -> GitWorkspaceSnapshot {
        GitWorkspaceSnapshot(
            repoRoot: "/tmp/repo",
            currentBranch: "main",
            entries: entries,
            aheadCount: ahead,
            behindCount: behind,
            hasUpstream: true,
            recentCommits: [],
            lastRefreshedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
