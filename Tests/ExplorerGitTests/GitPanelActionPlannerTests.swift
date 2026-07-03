import XCTest
@testable import Explorer

final class GitPanelActionPlannerTests: XCTestCase {
    func testDirtyPrimaryActionIsCommitAndSync() {
        let snapshot = makeSnapshot(entries: [GitPorcelainEntry(status: .modified, path: "a.swift")])
        let action = GitPanelActionPlanner.primaryAction(snapshot: snapshot, isOperating: false)
        XCTAssertEqual(action?.kind, .commitAndSync)
        XCTAssertEqual(action?.title, L10n.Git.Action.commitAndSync)
        XCTAssertTrue(action?.isEnabled == true)
    }

    func testCleanSyncedPrimaryActionIsSync() {
        let snapshot = makeSnapshot(entries: [])
        let action = GitPanelActionPlanner.primaryAction(snapshot: snapshot, isOperating: false)
        XCTAssertEqual(action?.kind, .sync)
        XCTAssertTrue(action?.isEnabled == true)
    }

    func testAheadOnlyPrimaryActionIsPush() {
        let snapshot = makeSnapshot(entries: [], ahead: 2)
        let action = GitPanelActionPlanner.primaryAction(snapshot: snapshot, isOperating: false)
        XCTAssertEqual(action?.kind, .push)
        XCTAssertTrue(action?.isEnabled == true)
    }

    func testPullDisabledWhenDirty() {
        let snapshot = makeSnapshot(
            entries: [GitPorcelainEntry(status: .modified, path: "a.swift")],
            ahead: 0,
            behind: 2
        )
        XCTAssertFalse(GitPanelActionPlanner.canPull(snapshot: snapshot))
        XCTAssertEqual(
            GitPanelActionPlanner.pullDisabledReason(snapshot: snapshot),
            L10n.Git.Error.pullWithDirty
        )
    }

    func testPullDisabledWhenConflict() {
        let snapshot = makeSnapshot(
            entries: [GitPorcelainEntry(status: .conflict, path: "a.swift")],
            behind: 1
        )
        let action = GitPanelActionPlanner.primaryAction(snapshot: snapshot, isOperating: false)
        XCTAssertEqual(action?.kind, .pull)
        XCTAssertFalse(action?.isEnabled == true)
        XCTAssertEqual(action?.disabledReason, L10n.Git.Error.conflict)
    }

    func testLargeCommitConfirmationThreshold() {
        XCTAssertFalse(GitPanelActionPlanner.shouldConfirmLargeCommit(changeCount: 50))
        XCTAssertTrue(GitPanelActionPlanner.shouldConfirmLargeCommit(changeCount: 51))
    }

    func testOperatingDisablesPrimaryAction() {
        let snapshot = makeSnapshot(entries: [])
        let action = GitPanelActionPlanner.primaryAction(snapshot: snapshot, isOperating: true)
        XCTAssertFalse(action?.isEnabled == true)
    }

    private func makeSnapshot(
        entries: [GitPorcelainEntry],
        ahead: Int = 0,
        behind: Int = 0,
        hasUpstream: Bool = true
    ) -> GitWorkspaceSnapshot {
        GitWorkspaceSnapshot(
            repoRoot: "/tmp/repo",
            currentBranch: "main",
            entries: entries,
            aheadCount: ahead,
            behindCount: behind,
            hasUpstream: hasUpstream,
            recentCommits: [],
            lastRefreshedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
