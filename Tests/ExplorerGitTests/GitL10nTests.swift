import XCTest
@testable import Explorer

final class GitL10nTests: XCTestCase {
    func testGitPanelStringsResolve() {
        XCTAssertNotEqual(L10n.Git.Panel.title, "git.panel.title")
        XCTAssertNotEqual(L10n.Git.Panel.close, "git.panel.close")
        XCTAssertNotEqual(L10n.Git.Panel.collapse, "git.panel.collapse")
        XCTAssertNotEqual(L10n.Git.Panel.expand, "git.panel.expand")
        XCTAssertNotEqual(L10n.Git.Panel.placeholder, "git.panel.placeholder")
        XCTAssertNotEqual(L10n.Git.Panel.refresh, "git.panel.refresh")
        XCTAssertNotEqual(L10n.Git.Status.clean, "git.status.clean")
        XCTAssertNotEqual(L10n.Git.Status.dirty(2), "git.status.dirty %lld")
        XCTAssertNotEqual(L10n.Git.Empty.notRepo, "git.empty.not_repo")
        XCTAssertNotEqual(L10n.Git.Action.commitAndSync, "git.action.commit_and_sync")
        XCTAssertNotEqual(L10n.Git.Commit.placeholder, "git.commit.placeholder")
        XCTAssertNotEqual(L10n.Git.Error.pullWithDirty, "git.error.pull_with_dirty")
        XCTAssertNotEqual(L10n.Git.History.title, "git.history.title")
        XCTAssertNotEqual(L10n.Menu.showGit, "menu.show_git")
        XCTAssertNotEqual(L10n.Menu.hideGit, "menu.hide_git")
    }
}
