import XCTest
@testable import Explorer

final class TrashLoaderTests: XCTestCase {
    func testIsTrashInputAcceptsLocalizedAndLegacyLabels() {
        XCTAssertTrue(TrashLoader.isTrashInput(TrashLoader.displayName))
        XCTAssertTrue(TrashLoader.isTrashInput(TrashLoader.legacyChineseDisplayName))
        XCTAssertTrue(TrashLoader.isTrashInput("Trash"))
        XCTAssertTrue(TrashLoader.isTrashInput(TrashLoader.pathToken))
        XCTAssertFalse(TrashLoader.isTrashInput("/Users/test"))
    }
}

final class FavoriteItemMigrationTests: XCTestCase {
    func testLegacyNameMigratesToKind() {
        let home = FavoriteItem(path: "/Users/me", name: "Home", icon: "house")
        XCTAssertEqual(home.kind, .home)
        XCTAssertNil(home.customName)
        XCTAssertFalse(home.displayName.isEmpty)
    }

    func testCustomLegacyNamePreservesCustomKind() {
        let item = FavoriteItem(path: "/tmp/work", name: "Work", icon: "folder")
        XCTAssertEqual(item.kind, .custom)
        XCTAssertEqual(item.customName, "Work")
        XCTAssertEqual(item.displayName, "Work")
    }

    func testEncodesKindInsteadOfLegacyName() throws {
        let item = FavoriteItem(path: "/Users/me/Desktop", kind: .desktop, icon: "desktopcomputer")
        let data = try JSONEncoder().encode(item)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["kind"] as? String, "desktop")
        XCTAssertNil(json?["name"])
    }
}
