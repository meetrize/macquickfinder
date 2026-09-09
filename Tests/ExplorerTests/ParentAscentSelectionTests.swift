import XCTest
@testable import Explorer

final class ParentAscentSelectionTests: XCTestCase {
    func testDirectParentSelectsChild() {
        let selected = ParentAscentSelection.childToSelect(
            from: "/Volumes/SSD4T/pro/www",
            to: "/Volumes/SSD4T/pro"
        )
        XCTAssertEqual(selected, "/Volumes/SSD4T/pro/www")
    }

    func testGrandparentSelectsNextSegment() {
        let selected = ParentAscentSelection.childToSelect(
            from: "/Volumes/SSD4T/pro/www",
            to: "/Volumes/SSD4T"
        )
        XCTAssertEqual(selected, "/Volumes/SSD4T/pro")
    }

    func testVolumesRootSelectsVolumeName() {
        let selected = ParentAscentSelection.childToSelect(
            from: "/Volumes/SSD4T/pro/www",
            to: "/Volumes"
        )
        XCTAssertEqual(selected, "/Volumes/SSD4T")
    }

    func testFilesystemRootSelectsFirstComponent() {
        let selected = ParentAscentSelection.childToSelect(
            from: "/Volumes/SSD4T/pro",
            to: "/"
        )
        XCTAssertEqual(selected, "/Volumes")
    }

    func testUnrelatedPathsReturnNil() {
        XCTAssertNil(
            ParentAscentSelection.childToSelect(
                from: "/Volumes/SSD4T/pro/www",
                to: "/Users/meetrice"
            )
        )
    }

    func testEqualPathsReturnNil() {
        XCTAssertNil(
            ParentAscentSelection.childToSelect(
                from: "/Volumes/SSD4T/pro",
                to: "/Volumes/SSD4T/pro"
            )
        )
    }

    func testDescendingIntoChildReturnsNil() {
        XCTAssertNil(
            ParentAscentSelection.childToSelect(
                from: "/Volumes/SSD4T/pro",
                to: "/Volumes/SSD4T/pro/www"
            )
        )
    }

    func testTrailingSlashAndDoubleSlashNormalize() {
        let selected = ParentAscentSelection.childToSelect(
            from: "/Volumes/SSD4T/pro/www/",
            to: "/Volumes/SSD4T/pro//"
        )
        XCTAssertEqual(selected, "/Volumes/SSD4T/pro/www")
    }

    func testTrashUnderHomeIsDescendant() {
        // 纯路径上 .Trash 是 Home 的子项；离开废纸篓时由 ContentView 跳过，避免高亮隐藏项。
        let selected = ParentAscentSelection.childToSelect(
            from: "/Users/meetrice/.Trash",
            to: "/Users/meetrice"
        )
        XCTAssertEqual(selected, "/Users/meetrice/.Trash")
    }

    func testSiblingPathsReturnNil() {
        XCTAssertNil(
            ParentAscentSelection.childToSelect(
                from: "/Volumes/SSD4T/pro/www",
                to: "/Volumes/SSD4T/pro/docs"
            )
        )
    }
}
