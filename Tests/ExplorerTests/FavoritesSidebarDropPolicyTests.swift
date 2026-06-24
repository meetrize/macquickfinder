import XCTest
@testable import Explorer

final class FavoritesSidebarDropPolicyTests: XCTestCase {
    func testInsertBeforeIndexUsesRowMidY() {
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.insertBeforeIndex(
                locationY: 10,
                rowAtLocation: 2,
                rowCount: 5,
                rowMidY: 20
            ),
            2
        )
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.insertBeforeIndex(
                locationY: 25,
                rowAtLocation: 2,
                rowCount: 5,
                rowMidY: 20
            ),
            3
        )
    }

    func testInsertBeforeIndexWhenBelowLastRow() {
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.insertBeforeIndex(
                locationY: 100,
                rowAtLocation: -1,
                rowCount: 3,
                rowMidY: nil
            ),
            3
        )
    }

    func testIsDropOntoRowCenterRejectsEdgeBands() {
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.isDropOntoRowCenter(
                locationY: 2,
                rowMinY: 0,
                rowHeight: 24
            )
        )
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.isDropOntoRowCenter(
                locationY: 12,
                rowMinY: 0,
                rowHeight: 24
            )
        )
    }

    func testCanDropOntoFavoriteRejectsSamePathAndDescendants() {
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: "/tmp/a",
                sourcePaths: ["/tmp/a"]
            )
        )
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: "/tmp/a",
                sourcePaths: ["/tmp/a/sub/file.txt"]
            )
        )
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: "/tmp/a",
                sourcePaths: ["/tmp/b/file.txt"]
            )
        )
    }

    func testDestinationPathUsesPendingRow() {
        let items = [
            FavoriteItem(path: "/a", name: "A", icon: "folder"),
            FavoriteItem(path: "/b", name: "B", icon: "folder"),
        ]
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.destinationPath(for: items, pendingDropRow: 1),
            "/b"
        )
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.destinationPath(for: items, pendingDropRow: -1),
            "/a"
        )
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.destinationPath(for: [], pendingDropRow: 0),
            ""
        )
    }

    func testShouldRejectReorderWhenSameLocation() {
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.shouldRejectReorder(
                draggedPath: "/",
                ontoTargetPath: "/System/Volumes/Data"
            )
        )
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.shouldRejectReorder(
                draggedPath: "/tmp/a",
                ontoTargetPath: "/tmp/b"
            )
        )
    }

    func testClampedInsertIndex() {
        XCTAssertEqual(FavoritesSidebarDropPolicy.clampedInsertIndex(-3, itemCount: 4), 0)
        XCTAssertEqual(FavoritesSidebarDropPolicy.clampedInsertIndex(2, itemCount: 4), 2)
        XCTAssertEqual(FavoritesSidebarDropPolicy.clampedInsertIndex(99, itemCount: 4), 4)
    }
}
