import XCTest
@testable import Explorer

final class PathNavigationHistoryTests: XCTestCase {
    func testRecordNavigationClearsForwardStack() {
        var history = PathNavigationHistory()
        history.recordNavigation(from: "/a", to: "/b")
        _ = history.goBack(from: "/b")
        XCTAssertTrue(history.canGoForward)

        history.recordNavigation(from: "/a", to: "/c")
        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.backStack, ["/a"])
    }

    func testBackAndForwardRoundTrip() {
        var history = PathNavigationHistory()
        history.recordNavigation(from: "/a", to: "/b")
        history.recordNavigation(from: "/b", to: "/c")

        XCTAssertEqual(history.goBack(from: "/c"), "/b")
        XCTAssertEqual(history.goBack(from: "/b"), "/a")
        XCTAssertFalse(history.canGoBack)

        XCTAssertEqual(history.goForward(from: "/a"), "/b")
        XCTAssertEqual(history.goForward(from: "/b"), "/c")
        XCTAssertFalse(history.canGoForward)
    }

    func testTrailAndRecentEntries() {
        var history = PathNavigationHistory()
        history.recordNavigation(from: "/a", to: "/b")
        history.recordNavigation(from: "/b", to: "/c")
        _ = history.goBack(from: "/c")

        XCTAssertEqual(history.trail(currentPath: "/b"), ["/a", "/b", "/c"])
        XCTAssertEqual(history.recentEntries(currentPath: "/b"), ["/c", "/b", "/a"])
    }

    func testJumpRebuildsStacks() {
        var history = PathNavigationHistory()
        history.recordNavigation(from: "/a", to: "/b")
        history.recordNavigation(from: "/b", to: "/c")

        history.jump(to: "/a", from: "/c")
        XCTAssertEqual(history.backStack, [])
        XCTAssertEqual(history.forwardStack, ["/c", "/b"])
    }
}
