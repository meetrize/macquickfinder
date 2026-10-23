import XCTest
@testable import Explorer

@MainActor
final class ExplorerPaneStateTests: XCTestCase {
    func testReleaseResourcesClearsListingAndBumpsGeneration() {
        let pane = ExplorerPaneState(id: .secondary, path: "/tmp")
        let generationBefore = pane.loadGeneration
        pane.selection = ["/tmp/a.txt"]
        pane.isLoading = true

        pane.releaseResources()

        XCTAssertTrue(pane.items.isEmpty)
        XCTAssertTrue(pane.selection.isEmpty)
        XCTAssertFalse(pane.isLoading)
        XCTAssertEqual(pane.loadGeneration, generationBefore &+ 1)
        XCTAssertEqual(pane.path, "/tmp")
    }

    func testNavigateToDirectoryUpdatesPathWithoutLoadingHiddenDefault() {
        let pane = ExplorerPaneState(id: .secondary, path: "/tmp")
        pane.navigateToDirectory("/Users")
        XCTAssertEqual(pane.path, "/Users")
        XCTAssertTrue(pane.selection.isEmpty)
    }

    func testAdoptSnapshotReplacesListing() {
        let pane = ExplorerPaneState(id: .secondary, path: "/tmp")
        pane.adoptSnapshot(path: "/Users", items: [], selection: [])
        XCTAssertEqual(pane.path, "/Users")
        XCTAssertTrue(pane.items.isEmpty)
    }
}
