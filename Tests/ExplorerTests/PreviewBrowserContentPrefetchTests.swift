import AppKit
import XCTest
@testable import Explorer

@MainActor
final class PreviewBrowserContentPrefetchTests: XCTestCase {
    func testHasCachedReflectsSeededEntry() throws {
        let prefetcher = PreviewBrowserContentPrefetcher()
        let data = Data([0x89, 0x50, 0x4E, 0x47])

        XCTAssertFalse(prefetcher.hasCached(for: "item-a"))
        prefetcher.seedEntryForTesting(itemID: "item-a", data: data)
        XCTAssertTrue(prefetcher.hasCached(for: "item-a"))
        XCTAssertEqual(prefetcher.consume(for: "item-a"), data)
        XCTAssertFalse(prefetcher.hasCached(for: "item-a"))
    }

    func testTryApplyPrefetchedBrowseContentShowsImageWithoutLoadingPhase() async throws {
        let pngURL = try makeTemporaryPNG(width: 32, height: 24)
        defer { try? FileManager.default.removeItem(at: pngURL) }

        let pngData = try Data(contentsOf: pngURL)
        let current = makeFileItem(id: pngURL.path, url: pngURL, name: pngURL.lastPathComponent, ext: "png")
        let neighborURL = try makeTemporaryPNG(width: 16, height: 16)
        defer { try? FileManager.default.removeItem(at: neighborURL) }
        let neighbor = makeFileItem(
            id: neighborURL.path,
            url: neighborURL,
            name: neighborURL.lastPathComponent,
            ext: "png"
        )

        let context = PreviewBrowserContext(
            directoryPath: pngURL.deletingLastPathComponent().path,
            sortSnapshot: FileListSortState(sortOrder: .nameAscending),
            showHiddenFiles: false,
            sourceItems: [current, neighbor],
            sameTypeOnly: false,
            orderedItems: [current, neighbor],
            currentIndex: 0
        )

        let session = PreviewSession(hostWindowID: UUID(), file: current)
        session.attachBrowserContext(context)
        session.browseNext()
        session.browseContentPrefetcher.seedEntryForTesting(itemID: neighbor.id, data: pngData)

        let applied = await session.tryApplyPrefetchedBrowseContent()

        XCTAssertTrue(applied)
        XCTAssertNotNil(session.content.image)
        XCTAssertEqual(session.content.loadPhase, .loaded)
        XCTAssertFalse(session.isLoading)
    }

    private func makeFileItem(id: String, url: URL, name: String, ext: String) -> FileItem {
        FileItem(
            id: id,
            url: url,
            name: name,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: Int64((try? Data(contentsOf: url).count) ?? 1024),
            isHidden: false,
            fileType: ext,
            sizeDisplay: "1 KB",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    private func makeTemporaryPNG(width: Int, height: Int) throws -> URL {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            throw NSError(domain: "PreviewBrowserContentPrefetchTests", code: 1)
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "PreviewBrowserContentPrefetchTests", code: 2)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prefetch-test-\(UUID().uuidString).png")
        try pngData.write(to: url)
        return url
    }
}
