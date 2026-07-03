import XCTest
@testable import Explorer

final class GitStatusPresentationTests: XCTestCase {
    private func makeSnapshot(
        branch: String? = "main",
        entries: [GitPorcelainEntry] = [],
        ahead: Int = 0,
        behind: Int = 0,
        hasUpstream: Bool = true
    ) -> GitWorkspaceSnapshot {
        GitWorkspaceSnapshot(
            repoRoot: "/tmp/repo",
            currentBranch: branch,
            entries: entries,
            aheadCount: ahead,
            behindCount: behind,
            hasUpstream: hasUpstream,
            lastRefreshedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testStatusStripIncludesBranchAndChanges() {
        let snapshot = makeSnapshot(
            entries: [GitPorcelainEntry(status: .modified, path: "a.swift")],
            ahead: 1
        )
        let strip = GitStatusPresentation.statusStrip(snapshot: snapshot)
        XCTAssertTrue(strip.contains("main"))
        XCTAssertTrue(strip.contains("1"))
    }

    func testChipLabelShowsChangeCountBadge() {
        let snapshot = makeSnapshot(
            entries: [
                GitPorcelainEntry(status: .modified, path: "a.swift"),
                GitPorcelainEntry(status: .added, path: "b.swift"),
            ]
        )
        XCTAssertTrue(GitStatusPresentation.chipLabel(snapshot: snapshot).contains("2●"))
    }

    func testVisibleEntriesTruncatesToEight() {
        let entries = (0..<10).map {
            GitPorcelainEntry(status: .modified, path: "file-\($0).swift")
        }
        let listing = GitStatusPresentation.visibleEntries(from: entries, showsAll: false)
        XCTAssertEqual(listing.visible.count, 8)
        XCTAssertEqual(listing.remainingCount, 2)
    }

    func testAbsolutePathJoinsRepoRoot() {
        let entry = GitPorcelainEntry(status: .modified, path: "Sources/A.swift")
        XCTAssertEqual(
            GitStatusPresentation.absolutePath(for: entry, repoRoot: "/repo"),
            "/repo/Sources/A.swift"
        )
    }
}
