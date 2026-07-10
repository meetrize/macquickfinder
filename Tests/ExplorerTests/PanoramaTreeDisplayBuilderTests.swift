import FileList
import XCTest

@testable import Explorer

final class PanoramaTreeDisplayBuilderTests: XCTestCase {
    func testThreeLevelNestedStructureWhenExpanded() {
        let root = "/tmp/root"
        let photos = "\(root)/Photos"
        let vacation = "\(photos)/Vacation"
        let year = "\(vacation)/2024"

        let snapshot = makeSnapshot(
            rootPath: root,
            rootItems: [folder(photos, name: "Photos"), file("\(root)/readme.txt", name: "readme.txt")],
            listings: [
                ListingFixture(path: photos, depth: 0, items: [folder(vacation, name: "Vacation")]),
                ListingFixture(path: vacation, depth: 1, items: [
                    folder(year, name: "2024"),
                    file("\(vacation)/note.txt", name: "note.txt"),
                ]),
                ListingFixture(path: year, depth: 2, items: [file("\(year)/img.jpg", name: "img.jpg")]),
            ]
        )

        let display = PanoramaTreeDisplayBuilder.build(snapshot: snapshot)

        XCTAssertEqual(display.blocks.count, 2)
        guard case let .expandedFolderSection(photosRow, _) = display.blocks[0] else {
            return XCTFail("Expected Photos expanded folder section first")
        }
        XCTAssertEqual(photosRow.name, "Photos")
        XCTAssertEqual(photosRow.depth, 0)

        guard case let .itemGrid(rootGridDepth, rootGridID, _, rootGridItems) = display.blocks[1] else {
            return XCTFail("Expected root item grid after Photos")
        }
        XCTAssertEqual(rootGridDepth, 0)
        XCTAssertEqual(rootGridID, root)
        XCTAssertEqual(rootGridItems.count, 1)
        guard case let .file(row) = rootGridItems[0] else {
            return XCTFail("Expected readme file in root grid")
        }
        XCTAssertEqual(row.name, "readme.txt")

        XCTAssertTrue(blockContainsExpandedFolder(named: "Vacation", in: display.blocks))
    }

    func testSiblingDirectoriesPreserveSortOrderWhenMixedExpandState() {
        let root = "/tmp/root"
        let archive = "\(root)/Archive"
        let photos = "\(root)/Photos"
        let videos = "\(root)/Videos"

        var collapse = PanoramaTreeCollapseState()
        collapse.collapse(archive)
        collapse.collapse(videos)

        let snapshot = makeSnapshot(
            rootPath: root,
            rootItems: [
                folder(archive, name: "Archive"),
                folder(photos, name: "Photos"),
                folder(videos, name: "Videos"),
            ],
            listings: [
                ListingFixture(path: archive, depth: 0, items: [file("\(archive)/a.txt", name: "a.txt")]),
                ListingFixture(path: photos, depth: 0, items: [file("\(photos)/b.txt", name: "b.txt")]),
                ListingFixture(path: videos, depth: 0, items: [file("\(videos)/c.txt", name: "c.txt")]),
            ],
            collapseState: collapse
        )

        let display = PanoramaTreeDisplayBuilder.build(snapshot: snapshot)
        XCTAssertEqual(display.blocks.count, 3)

        guard case let .itemGrid(_, _, _, firstGridItems) = display.blocks[0],
              case let .folderCollapsed(firstFolder) = firstGridItems[0] else {
            return XCTFail("Expected collapsed Archive grid first")
        }
        XCTAssertEqual(firstFolder.name, "Archive")

        guard case let .expandedFolderSection(photosRow, _) = display.blocks[1] else {
            return XCTFail("Expected expanded Photos second")
        }
        XCTAssertEqual(photosRow.name, "Photos")

        guard case let .itemGrid(_, _, _, thirdGridItems) = display.blocks[2],
              case let .folderCollapsed(thirdFolder) = thirdGridItems[0] else {
            return XCTFail("Expected collapsed Videos grid third")
        }
        XCTAssertEqual(thirdFolder.name, "Videos")

        XCTAssertNotEqual(display.blocks[0].id, display.blocks[2].id)
    }

    func testCollapsedDirectoryAppearsInParentGridOnly() {
        let root = "/tmp/root"
        let photos = "\(root)/Photos"

        var collapse = PanoramaTreeCollapseState()
        collapse.collapse(photos)

        let snapshot = makeSnapshot(
            rootPath: root,
            rootItems: [folder(photos, name: "Photos"), file("\(root)/a.txt", name: "a.txt")],
            listings: [ListingFixture(path: photos, depth: 0, items: [file("\(photos)/b.txt", name: "b.txt")])],
            collapseState: collapse
        )

        let display = PanoramaTreeDisplayBuilder.build(snapshot: snapshot)
        XCTAssertFalse(flatBlocks(from: display).contains { block in
            if case let .expandedFolderSection(row, _) = block { return row.id == photos }
            return false
        })

        guard case let .itemGrid(_, _, _, items) = display.blocks.first else {
            return XCTFail("Expected only root grid")
        }
        XCTAssertEqual(items.count, 2)
        guard case let .folderCollapsed(folderRow) = items[0] else {
            return XCTFail("Expected collapsed Photos folder first")
        }
        XCTAssertEqual(folderRow.name, "Photos")
    }

    func testEmptyDirectoryHasNoExpandedSectionAndAppearsInParentGrid() {
        let root = "/tmp/root"
        let empty = "\(root)/Empty"

        let snapshot = makeSnapshot(
            rootPath: root,
            rootItems: [folder(empty, name: "Empty")],
            listings: [ListingFixture(path: empty, depth: 0, items: [])]
        )

        let display = PanoramaTreeDisplayBuilder.build(snapshot: snapshot)
        let flat = flatBlocks(from: display)
        XCTAssertFalse(flat.contains { block in
            if case let .expandedFolderSection(row, _) = block { return row.id == empty }
            return false
        })

        guard case let .itemGrid(_, _, _, items) = display.blocks.first else {
            return XCTFail("Expected root grid")
        }
        XCTAssertEqual(items.count, 1)
        guard case let .folderCollapsed(row) = items[0] else {
            return XCTFail("Expected empty folder cell")
        }
        XCTAssertEqual(row.name, "Empty")
    }

    func testGridCapAddsOverflowForManyFiles() {
        let root = "/tmp/root"
        var files: [FileItem] = []
        files.reserveCapacity(100)
        for index in 0..<100 {
            files.append(file("\(root)/file-\(index).txt", name: "file-\(index).txt"))
        }

        let snapshot = makeSnapshot(rootPath: root, rootItems: files, listings: [])
        let display = PanoramaTreeDisplayBuilder.build(snapshot: snapshot)

        guard case let .itemGrid(_, _, _, items) = display.blocks.first else {
            return XCTFail("Expected root grid")
        }
        XCTAssertEqual(items.count, 48)
        guard case let .overflow(directoryID, remaining) = items.last else {
            return XCTFail("Expected overflow item")
        }
        XCTAssertEqual(directoryID, root)
        XCTAssertEqual(remaining, 53)
    }

    // MARK: - Fixtures

    private struct ListingFixture {
        let path: String
        let depth: Int
        let items: [FileItem]
    }

    private func makeSnapshot(
        rootPath: String,
        rootItems: [FileItem],
        listings: [ListingFixture],
        collapseState: PanoramaTreeCollapseState = PanoramaTreeCollapseState()
    ) -> PanoramaTreeDisplayBuilder.Snapshot {
        var nodes: [String: PanoramaDirectoryNode] = [:]

        for item in rootItems where item.isDirectory {
            nodes[item.id] = PanoramaDirectoryNode(item: item, depth: 0)
        }

        for fixture in listings {
            let folderItem: FileItem
            if let existing = nodes[fixture.path] {
                folderItem = existing.item
            } else {
                let name = URL(fileURLWithPath: fixture.path).lastPathComponent
                folderItem = folder(fixture.path, name: name)
            }

            nodes[fixture.path] = PanoramaDirectoryNode(
                item: folderItem,
                depth: fixture.depth,
                listing: .loaded(fixture.items)
            )

            for item in fixture.items where item.isDirectory {
                if nodes[item.id] == nil {
                    nodes[item.id] = PanoramaDirectoryNode(item: item, depth: fixture.depth + 1)
                }
            }
        }

        return PanoramaTreeDisplayBuilder.Snapshot(
            rootDirectoryPath: rootPath,
            rootListing: .loaded(rootItems),
            nodesByPath: nodes,
            collapseState: collapseState
        )
    }

    private func flatBlocks(from display: PanoramaDisplayRoot) -> [PanoramaDisplayBlock] {
        flatten(display.blocks)
    }

    private func flatten(_ blocks: [PanoramaDisplayBlock]) -> [PanoramaDisplayBlock] {
        var result: [PanoramaDisplayBlock] = []
        for block in blocks {
            result.append(block)
            switch block {
            case let .expandedFolderSection(_, children):
                result.append(contentsOf: flatten(children))
            case let .childBlocks(_, children):
                result.append(contentsOf: flatten(children))
            case .itemGrid:
                break
            }
        }
        return result
    }

    private func blockContainsExpandedFolder(named name: String, in blocks: [PanoramaDisplayBlock]) -> Bool {
        flatten(blocks).contains { block in
            if case let .expandedFolderSection(row, _) = block { return row.name == name }
            return false
        }
    }

    private func folder(_ path: String, name: String) -> FileItem {
        FileItem(
            id: path,
            url: URL(fileURLWithPath: path, isDirectory: true),
            name: name,
            isDirectory: true,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "Folder",
            sizeDisplay: "--",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    private func file(_ path: String, name: String) -> FileItem {
        FileItem(
            id: path,
            url: URL(fileURLWithPath: path),
            name: name,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 128,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "128 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }
}
