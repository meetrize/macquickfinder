import XCTest
@testable import Explorer

@MainActor
final class PreviewStandaloneOpenPreferencesTests: XCTestCase {
    private func makeFileItem(ext: String, name: String? = nil) -> FileItem {
        let fileName = name ?? "sample.\(ext)"
        let path = "/tmp/\(fileName)"
        return FileItem(
            id: path,
            url: URL(fileURLWithPath: path),
            name: fileName,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 100,
            isHidden: false,
            fileType: ext,
            sizeDisplay: "100 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testImageOptionsFitToScreen() {
        let options = PreviewStandaloneOpenPreferences.options(for: makeFileItem(ext: "png"))
        XCTAssertTrue(options.fitImageToScreen)
        XCTAssertNil(options.initialWindowSize)
        XCTAssertFalse(options.allowsDockBack)
    }

    func testPDFOptionsUseDocumentSize() {
        let options = PreviewStandaloneOpenPreferences.options(for: makeFileItem(ext: "pdf"))
        XCTAssertFalse(options.fitImageToScreen)
        XCTAssertEqual(options.initialWindowSize, CGSize(width: 800, height: 1000))
    }

    func testTextOptionsUseEditorSize() {
        let options = PreviewStandaloneOpenPreferences.options(for: makeFileItem(ext: "swift"))
        XCTAssertEqual(options.initialWindowSize, CGSize(width: 720, height: 900))
    }

    func testMediaOptionsUseSixteenByNine() {
        let options = PreviewStandaloneOpenPreferences.options(for: makeFileItem(ext: "mp4"))
        XCTAssertEqual(options.initialWindowSize, CGSize(width: 960, height: 540))
    }

    func testOfficeOptionsUseQuickLookSize() {
        let options = PreviewStandaloneOpenPreferences.options(for: makeFileItem(ext: "pptx"))
        XCTAssertEqual(options.initialWindowSize, CGSize(width: 800, height: 600))
    }

    func testArchiveOptionsUseCompactSize() {
        let options = PreviewStandaloneOpenPreferences.options(for: makeFileItem(ext: "zip", name: "bundle.zip"))
        XCTAssertEqual(options.initialWindowSize, CGSize(width: 640, height: 480))
    }

    func testRouteMappingMatchesFileItem() {
        let file = makeFileItem(ext: "pdf")
        let route = PreviewLoadDispatch.resolve(
            PreviewLoadDispatchInput(
                pathExtension: "pdf",
                fileName: file.name,
                isHtmlFile: false,
                htmlPreviewMode: .preview,
                overridingMode: nil,
                supplementalMode: nil
            )
        )
        let fromFile = PreviewStandaloneOpenPreferences.options(for: file)
        let fromRoute = PreviewStandaloneOpenPreferences.options(for: route)
        XCTAssertEqual(fromFile, fromRoute)
    }
}

@MainActor
final class PreviewSessionStoreDetachedLookupTests: XCTestCase {
    func testDetachedSessionLookupByFileID() {
        let store = PreviewSessionStore.shared
        let file = FileItem(
            id: "/tmp/report.pdf",
            url: URL(fileURLWithPath: "/tmp/report.pdf"),
            name: "report.pdf",
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 100,
            isHidden: false,
            fileType: "pdf",
            sizeDisplay: "100 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let session = PreviewSession(hostWindowID: UUID(), file: file)
        session.location = .detached(windowNumber: 1)
        store.register(session)

        XCTAssertTrue(store.detachedSession(forFileID: file.id) === session)

        session.clearBrowserContext()
        store.remove(session.id)
    }
}

@MainActor
final class PreviewWindowValueInitialSizeTests: XCTestCase {
    func testInitialWindowSizeRoundTrip() throws {
        let value = PreviewWindowValue(
            sessionID: PreviewSessionID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
            fitImageToScreen: false,
            initialWindowSize: CGSize(width: 720, height: 900)
        )
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(PreviewWindowValue.self, from: data)
        XCTAssertEqual(decoded.initialWindowSize, CGSize(width: 720, height: 900))
    }
}
