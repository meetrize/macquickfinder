import XCTest
@testable import Explorer

@MainActor
final class ExternalPreviewOpenCenterTests: XCTestCase {
    override func tearDown() {
        ExternalPreviewOpenCenter.shared.clearSuppressExplorerWindows()
        let store = PreviewSessionStore.shared
        Array(store.sessions.keys).forEach { store.remove($0) }
        super.tearDown()
    }

    func testTryOpenReturnsFalseForNonPreviewableURLs() {
        let urls = [
            URL(fileURLWithPath: "/tmp/readme.xyzunknown"),
            URL(fileURLWithPath: "/tmp/folder", isDirectory: true),
        ]
        XCTAssertFalse(ExternalPreviewOpenCenter.shared.tryOpen(urls: urls))
        XCTAssertFalse(ExternalPreviewOpenCenter.shared.shouldSuppressExplorerWindows)
    }

    func testTryOpenOpensSinglePreviewWindowForFirstPreviewableURL() {
        var openedValues: [PreviewWindowValue] = []
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedValues.append(value)
        }

        let opened = ExternalPreviewOpenCenter.shared.tryOpen(urls: [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.pdf"),
        ])

        XCTAssertTrue(opened)
        XCTAssertEqual(openedValues.count, 1)
        XCTAssertTrue(openedValues[0].fitImageToScreen)
    }

    func testTryOpenUsesTypeSpecificWindowSizeForPDF() {
        var openedValue: PreviewWindowValue?
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedValue = value
        }

        XCTAssertTrue(ExternalPreviewOpenCenter.shared.tryOpen(urls: [
            URL(fileURLWithPath: "/tmp/report.pdf"),
        ]))

        XCTAssertEqual(openedValue?.initialWindowSize, CGSize(width: 800, height: 1000))
        XCTAssertFalse(openedValue?.fitImageToScreen ?? true)
    }

    func testTryOpenOpensOneWindowPerImageWhenConfigured() {
        PreviewOpenPreferences.externalMultiImageOpen = .oneWindowPerFile
        var openedValues: [PreviewWindowValue] = []
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedValues.append(value)
        }

        let opened = ExternalPreviewOpenCenter.shared.tryOpen(urls: [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.png"),
        ])

        XCTAssertTrue(opened)
        XCTAssertEqual(openedValues.count, 2)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Preview.externalMultiImageOpen)
    }

    func testTryOpenLoadsSiblingDirectoryForBrowserStrip() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let a = directory.appendingPathComponent("a.png")
        let b = directory.appendingPathComponent("b.png")
        let c = directory.appendingPathComponent("c.png")
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngHeader.write(to: a)
        try pngHeader.write(to: b)
        try pngHeader.write(to: c)

        var openedSessionID: PreviewSessionID?
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedSessionID = value.sessionID
        }

        XCTAssertTrue(ExternalPreviewOpenCenter.shared.tryOpen(urls: [b]))

        let sessionID = try XCTUnwrap(openedSessionID)
        let session = try XCTUnwrap(PreviewSessionStore.shared.session(for: sessionID))
        let context = try XCTUnwrap(session.browseContext)
        XCTAssertTrue(context.canBrowse)
        XCTAssertEqual(context.count, 3)
        XCTAssertEqual(context.currentItem.id, b.path)
    }

    func testTryOpenMergesAdditionalSelectedURLsIntoBrowserStrip() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let a = directory.appendingPathComponent("a.png")
        let b = directory.appendingPathComponent("b.png")
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngHeader.write(to: a)
        try pngHeader.write(to: b)

        var openedSessionID: PreviewSessionID?
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedSessionID = value.sessionID
        }

        XCTAssertTrue(ExternalPreviewOpenCenter.shared.tryOpen(urls: [a, b]))

        let sessionID = try XCTUnwrap(openedSessionID)
        let session = try XCTUnwrap(PreviewSessionStore.shared.session(for: sessionID))
        let context = try XCTUnwrap(session.browseContext)
        XCTAssertTrue(context.canBrowse)
        XCTAssertEqual(context.count, 2)
        XCTAssertEqual(context.currentItem.id, a.path)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("external-preview-open-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
