import XCTest
@testable import Explorer

final class GitWorkspaceFSEventsPolicyTests: XCTestCase {
    private let repoRoot = "/Volumes/SSD4T/pro/macquickfinder"

    func testAcceptsWorkingTreeChanges() {
        XCTAssertTrue(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPath: repoRoot + "/Sources/Explorer/ContentView.swift",
                repoRoot: repoRoot
            )
        )
        XCTAssertTrue(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPaths: [repoRoot + "/README.md"],
                repoRoot: repoRoot
            )
        )
    }

    func testAcceptsRelevantGitMetadataChanges() {
        XCTAssertTrue(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPath: repoRoot + "/.git/index",
                repoRoot: repoRoot
            )
        )
        XCTAssertTrue(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPath: repoRoot + "/.git/HEAD",
                repoRoot: repoRoot
            )
        )
    }

    func testIgnoresObjectDatabaseAndReflogNoise() {
        XCTAssertFalse(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPath: repoRoot + "/.git/objects/pack/pack-123.pack",
                repoRoot: repoRoot
            )
        )
        XCTAssertFalse(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPath: repoRoot + "/.git/logs/HEAD",
                repoRoot: repoRoot
            )
        )
    }

    func testIgnoresTransientLockFiles() {
        XCTAssertFalse(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPath: repoRoot + "/.git/index.lock",
                repoRoot: repoRoot
            )
        )
    }

    func testIgnoresPathsOutsideRepository() {
        XCTAssertFalse(
            GitWorkspaceFSEventsPolicy.shouldRefresh(
                eventPath: "/tmp/other.txt",
                repoRoot: repoRoot
            )
        )
    }
}
