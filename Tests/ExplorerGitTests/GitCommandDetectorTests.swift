import XCTest
@testable import Explorer

final class GitCommandDetectorTests: XCTestCase {
    func testDetectsDirectMutatingCommands() {
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("git commit -m \"msg\""))
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("git add ."))
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("git pull --rebase"))
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("git push origin main"))
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("git reset --hard HEAD"))
    }

    func testDetectsChainedMutatingCommands() {
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("cd /repo && git add ."))
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("git status; git commit -m x"))
    }

    func testDetectsGitWithPathOption() {
        XCTAssertTrue(GitCommandDetector.mutatesWorkingTree("git -C /repo commit -m x"))
    }

    func testIgnoresReadOnlyGitCommands() {
        XCTAssertFalse(GitCommandDetector.mutatesWorkingTree("git status"))
        XCTAssertFalse(GitCommandDetector.mutatesWorkingTree("git log -1"))
        XCTAssertFalse(GitCommandDetector.mutatesWorkingTree("git diff"))
        XCTAssertFalse(GitCommandDetector.mutatesWorkingTree("git show HEAD"))
    }

    func testIgnoresNonGitCommands() {
        XCTAssertFalse(GitCommandDetector.mutatesWorkingTree("ls -la"))
        XCTAssertFalse(GitCommandDetector.mutatesWorkingTree("echo git commit"))
        XCTAssertFalse(GitCommandDetector.mutatesWorkingTree(""))
    }
}
