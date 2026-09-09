import XCTest
@testable import Explorer

final class PathBarBreadcrumbContextMenuBuilderTests: XCTestCase {
    func testItemOrderOpenFirstWithClipboard() {
        let snapshot = PathBarBreadcrumbContextMenuBuilder.Snapshot(
            pathExists: true,
            pathExistsAsDirectory: true,
            canFavorite: true,
            isFavorited: false,
            hasClipboardPath: true
        )

        XCTAssertEqual(
            PathBarBreadcrumbContextMenuBuilder.itemKinds(for: snapshot),
            [
                .openInNewWindow,
                .separator,
                .copyPath,
                .copyDirectoryName,
                .addFavorite,
                .separator,
                .openTerminalHere,
                .revealInFinder,
                .separator,
                .openClipboardPath,
            ]
        )
    }

    func testItemOrderShowsRemoveFavoriteWhenFavorited() {
        let snapshot = PathBarBreadcrumbContextMenuBuilder.Snapshot(
            pathExists: true,
            pathExistsAsDirectory: true,
            canFavorite: false,
            isFavorited: true,
            hasClipboardPath: false
        )

        XCTAssertEqual(
            PathBarBreadcrumbContextMenuBuilder.itemKinds(for: snapshot),
            [
                .openInNewWindow,
                .separator,
                .copyPath,
                .copyDirectoryName,
                .removeFavorite,
                .separator,
                .openTerminalHere,
                .revealInFinder,
            ]
        )
    }

    func testOmitsFavoriteWhenNeitherAddNorRemove() {
        let snapshot = PathBarBreadcrumbContextMenuBuilder.Snapshot(
            pathExists: true,
            pathExistsAsDirectory: true,
            canFavorite: false,
            isFavorited: false,
            hasClipboardPath: false
        )

        XCTAssertEqual(
            PathBarBreadcrumbContextMenuBuilder.itemKinds(for: snapshot),
            [
                .openInNewWindow,
                .separator,
                .copyPath,
                .copyDirectoryName,
                .separator,
                .openTerminalHere,
                .revealInFinder,
            ]
        )
    }

    func testItemKindsCanOmitClipboardEvenWhenPresent() {
        let snapshot = PathBarBreadcrumbContextMenuBuilder.Snapshot(
            pathExists: true,
            pathExistsAsDirectory: true,
            canFavorite: true,
            isFavorited: false,
            hasClipboardPath: true
        )

        XCTAssertFalse(
            PathBarBreadcrumbContextMenuBuilder.itemKinds(for: snapshot, includeClipboard: false)
                .contains(.openClipboardPath)
        )
    }

    func testSnapshotForExistingDirectory() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("pathbar-menu-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let snapshot = PathBarBreadcrumbContextMenuBuilder.snapshot(
            for: folder.path,
            isFavorited: { _ in false },
            clipboardHasPath: { true }
        )

        XCTAssertTrue(snapshot.pathExists)
        XCTAssertTrue(snapshot.pathExistsAsDirectory)
        XCTAssertTrue(snapshot.canFavorite)
        XCTAssertFalse(snapshot.isFavorited)
        XCTAssertTrue(snapshot.hasClipboardPath)
    }

    @MainActor
    func testMakeMenuDisablesOpenActionsWhenPathMissing() {
        let missing = "/tmp/meofind-pathbar-missing-\(UUID().uuidString)"
        let menu = PathBarBreadcrumbContextMenuBuilder.makeMenu(
            path: missing,
            actions: .empty,
            clipboardHasPath: { false }
        )

        let openWindow = menu.items.first { $0.title == L10n.Action.openInNewWindow }
        let terminal = menu.items.first { $0.title == L10n.Action.openTerminalHere }
        let reveal = menu.items.first { $0.title == L10n.Action.revealInFinder }
        let copyName = menu.items.first { $0.title == L10n.Action.copyDirectoryName }
        XCTAssertEqual(openWindow?.isEnabled, false)
        XCTAssertEqual(terminal?.isEnabled, false)
        XCTAssertEqual(reveal?.isEnabled, false)
        XCTAssertNotNil(copyName)
        XCTAssertNil(menu.items.first { $0.title == L10n.Action.openClipboardPath })
    }

    @MainActor
    func testMakeEllipsisMenuBuildsSubmenusAndClipboardOnce() {
        let segments = [
            PathBarBreadcrumbContextMenuBuilder.HiddenSegment(name: "a", path: "/tmp/a"),
            PathBarBreadcrumbContextMenuBuilder.HiddenSegment(name: "b", path: "/tmp/b"),
        ]
        let menu = PathBarBreadcrumbContextMenuBuilder.makeEllipsisMenu(
            segments: segments,
            actions: .empty,
            onNavigate: { _ in },
            clipboardHasPath: { true }
        )

        XCTAssertEqual(menu.items.count, 4) // a, b, separator, clipboard
        XCTAssertEqual(menu.items[0].title, "a")
        XCTAssertNotNil(menu.items[0].submenu)
        XCTAssertEqual(menu.items[1].title, "b")
        XCTAssertNotNil(menu.items[1].submenu)
        XCTAssertTrue(menu.items[2].isSeparatorItem)
        XCTAssertEqual(menu.items[3].title, L10n.Action.openClipboardPath)

        let submenuTitles = menu.items[0].submenu?.items.map(\.title) ?? []
        XCTAssertEqual(submenuTitles.first, L10n.Action.open)
        XCTAssertTrue(submenuTitles.contains(L10n.Action.copyDirectoryName))
        XCTAssertTrue(submenuTitles.contains(L10n.Action.revealInFinder))
        XCTAssertFalse(submenuTitles.contains(L10n.Action.openClipboardPath))
    }
}
