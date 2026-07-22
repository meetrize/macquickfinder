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

    func testHasContentsIgnoresDSStoreOnly() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-trash-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data().write(to: root.appendingPathComponent(".DS_Store"))
        XCTAssertFalse(TrashLoader.hasContents(in: [root]))

        let fileURL = root.appendingPathComponent("note.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(TrashLoader.hasContents(in: [root]))
    }

    func testRemoveContentsWithFileManagerClearsItems() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-trash-clear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("gone.txt")
        try "x".write(to: fileURL, atomically: true, encoding: .utf8)
        let nested = root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "y".write(to: nested.appendingPathComponent("inner.txt"), atomically: true, encoding: .utf8)

        let result = TrashLoader.removeContentsWithFileManager(in: [root])
        XCTAssertEqual(result.removedCount, 2)
        XCTAssertTrue(result.failedURLs.isEmpty)
        XCTAssertFalse(TrashLoader.hasContents(in: [root]))
    }
}

final class EmptyTrashFailureClassificationTests: XCTestCase {
    func testBenignEmptyTrashMarkers() {
        XCTAssertTrue(FileOperations.isBenignEmptyTrashFailure(
            output: "already_empty",
            errorOutput: ""
        ))
        XCTAssertTrue(FileOperations.isBenignEmptyTrashFailure(
            output: "",
            errorOutput: "The trash is empty."
        ))
        XCTAssertFalse(FileOperations.isBenignEmptyTrashFailure(
            output: "",
            errorOutput: "Finder 遇到一个错误，无法完成此操作"
        ))
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
