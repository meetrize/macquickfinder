import XCTest
@testable import FileList

final class FileListThumbnailSelectionTests: XCTestCase {
    func testGridRectSelectionSameRow() {
        let paths = FileListThumbnailCollectionLayoutSupport.indexPathsInGridRect(
            anchorItem: 1,
            targetItem: 3,
            columnCount: 4,
            itemCount: 12
        )
        XCTAssertEqual(paths, Set([
            IndexPath(item: 1, section: 0),
            IndexPath(item: 2, section: 0),
            IndexPath(item: 3, section: 0),
        ]))
    }

    func testGridRectSelectionAcrossRows() {
        let paths = FileListThumbnailCollectionLayoutSupport.indexPathsInGridRect(
            anchorItem: 2,
            targetItem: 5,
            columnCount: 4,
            itemCount: 12
        )
        XCTAssertEqual(paths, Set([
            IndexPath(item: 1, section: 0),
            IndexPath(item: 2, section: 0),
            IndexPath(item: 5, section: 0),
            IndexPath(item: 6, section: 0),
        ]))
    }

    func testGridRectSelectionSingleColumnList() {
        let paths = FileListThumbnailCollectionLayoutSupport.indexPathsInGridRect(
            anchorItem: 1,
            targetItem: 4,
            columnCount: 1,
            itemCount: 6
        )
        XCTAssertEqual(paths, Set([
            IndexPath(item: 1, section: 0),
            IndexPath(item: 2, section: 0),
            IndexPath(item: 3, section: 0),
            IndexPath(item: 4, section: 0),
        ]))
    }

    func testCollectionEffectiveSelectionIDsUnionsBindingAndCollection() {
        let ids = FileListInteractionCoordinator.collectionEffectiveSelectionIDs(
            selectionGet: { ["a"] },
            collectionSelectedIDs: ["b"]
        )
        XCTAssertEqual(ids, Set(["a", "b"]))
    }
}
