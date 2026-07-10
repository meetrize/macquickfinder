import XCTest

@testable import Explorer

final class PanoramaTreeCollapseStateTests: XCTestCase {
    func testDefaultIsFullyExpanded() {
        var state = PanoramaTreeCollapseState()
        XCTAssertTrue(state.isExpanded("/tmp/Photos"))
        XCTAssertTrue(state.isEmpty)
    }

    func testCollapseAndExpandSingleDirectory() {
        var state = PanoramaTreeCollapseState()
        state.collapse("/tmp/Photos")

        XCTAssertFalse(state.isExpanded("/tmp/Photos"))
        XCTAssertFalse(state.isEmpty)

        state.expand("/tmp/Photos")
        XCTAssertTrue(state.isExpanded("/tmp/Photos"))
    }

    func testExpandAllClearsCollapsedSet() {
        var state = PanoramaTreeCollapseState()
        state.collapse("/tmp/Photos")
        state.collapse("/tmp/Docs")

        state.expandAll()

        XCTAssertTrue(state.isEmpty)
        XCTAssertTrue(state.isExpanded("/tmp/Photos"))
    }

    func testCollapseAllMarksProvidedDirectories() {
        var state = PanoramaTreeCollapseState()
        state.collapseAll(directoryIDs: ["/tmp/Photos", "/tmp/Docs"])

        XCTAssertFalse(state.isExpanded("/tmp/Photos"))
        XCTAssertFalse(state.isExpanded("/tmp/Docs"))
        XCTAssertTrue(state.isExpanded("/tmp/Other"))
    }

    func testSubtreeVisibleRequiresExpandedAncestors() {
        let state = PanoramaTreeCollapseState()
        let ancestors = ["/tmp/Photos", "/tmp/Vacation"]

        var expanded = state
        XCTAssertTrue(expanded.isSubtreeVisible(for: "/tmp/2024", ancestorIDs: ancestors))

        var collapsedParent = state
        collapsedParent.collapse("/tmp/Photos")
        XCTAssertFalse(collapsedParent.isSubtreeVisible(for: "/tmp/2024", ancestorIDs: ancestors))
    }
}
