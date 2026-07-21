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

    func testShouldTreatAsDropOntoFavoriteRowPrefersInsertEdgesWhenAddable() {
        // 可收藏目录：边缘不走移入，保留插入横线。
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.shouldTreatAsDropOntoFavoriteRow(
                hasAddableDirectories: true,
                isOntoRowCenter: false,
                canDropOntoRow: true
            )
        )
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.shouldTreatAsDropOntoFavoriteRow(
                hasAddableDirectories: true,
                isOntoRowCenter: true,
                canDropOntoRow: true
            )
        )
        // 仅文件：可移入时整行有效。
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.shouldTreatAsDropOntoFavoriteRow(
                hasAddableDirectories: false,
                isOntoRowCenter: false,
                canDropOntoRow: true
            )
        )
        // 不可移入：仅中央作无效反馈。
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.shouldTreatAsDropOntoFavoriteRow(
                hasAddableDirectories: false,
                isOntoRowCenter: false,
                canDropOntoRow: false
            )
        )
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.shouldTreatAsDropOntoFavoriteRow(
                hasAddableDirectories: false,
                isOntoRowCenter: true,
                canDropOntoRow: false
            )
        )
    }

    func testFilterAddableDirectoryURLsExcludesBundlesAndFavorites() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoritesDropPolicy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let folder = tempRoot.appendingPathComponent("Notes", isDirectory: true)
        let app = tempRoot.appendingPathComponent("Demo.app", isDirectory: true)
        let framework = tempRoot.appendingPathComponent("Foo.framework", isDirectory: true)
        let file = tempRoot.appendingPathComponent("readme.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: framework, withIntermediateDirectories: true)
        try "hi".write(to: file, atomically: true, encoding: .utf8)

        let alreadyFavorite = tempRoot.appendingPathComponent("Pinned", isDirectory: true)
        try FileManager.default.createDirectory(at: alreadyFavorite, withIntermediateDirectories: true)

        let filtered = FavoritesSidebarDropPolicy.filterAddableDirectoryURLs(
            [folder, app, framework, file, alreadyFavorite]
        ) { path in
            path == alreadyFavorite.path
        }

        XCTAssertEqual(filtered.map(\.path), [folder.path])
    }

    func testCanDropOntoFavoriteRejectsInvalidMoves() {
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: "/tmp/a",
                sourcePaths: ["/tmp/a"]
            )
        )
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: "/tmp/a",
                sourcePaths: ["/tmp/a/file.txt"]
            )
        )
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: "/tmp/a",
                sourcePaths: ["/tmp/a/sub"]
            )
        )
        XCTAssertTrue(
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

    func testCanDropOntoDesktopAllowsMovingFromSubfolder() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.path
        let nestedFile = (desktop as NSString).appendingPathComponent("eeee/eee.png")
        let desktopFile = (desktop as NSString).appendingPathComponent("eee.png")
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: desktop,
                sourcePaths: [nestedFile]
            )
        )
        XCTAssertFalse(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: desktop,
                sourcePaths: [desktopFile]
            )
        )
        XCTAssertTrue(
            FavoritesSidebarDropPolicy.canDropOntoFavorite(
                destinationPath: desktop,
                sourcePaths: [(home as NSString).appendingPathComponent("Documents/note.txt")]
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
            ""
        )
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.destinationPath(for: [], pendingDropRow: 0),
            ""
        )
    }

    func testDestinationPathUsesResolvedSystemDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let item = FavoriteItem(
            path: (home as NSString).appendingPathComponent("Desktop"),
            kind: .desktop,
            icon: "desktopcomputer"
        )
        XCTAssertEqual(
            FavoritesSidebarDropPolicy.destinationPath(for: [item], pendingDropRow: 0),
            desktopURL.path
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
