import XCTest
@testable import Explorer

final class EpubPreviewLoaderTests: XCTestCase {
    private var createdURLs: [URL] = []

    override func tearDown() {
        for url in createdURLs {
            try? FileManager.default.removeItem(at: url)
        }
        createdURLs.removeAll()
        super.tearDown()
    }

    func testLoadMinimalEpubPackage() throws {
        let epubURL = try makeSampleEpub()
        let package = try EpubPreviewLoader.load(from: epubURL)

        XCTAssertEqual(package.metadata.title, "Test Book")
        XCTAssertEqual(package.metadata.author, "Test Author")
        XCTAssertEqual(package.chapters.count, 1)
        XCTAssertEqual(package.chapters[0].id, "ch1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.chapters[0].fileURL.path))
        XCTAssertTrue(package.chapters[0].fileURL.path.hasSuffix("chapter1.xhtml"))

        EpubPreviewLoader.cleanup(extractedRoot: package.extractedRoot)
    }

    func testLoadEpubReturnsLocalizedErrorForInvalidArchive() async {
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-invalid-\(UUID().uuidString).epub")
        createdURLs.append(invalidURL)
        try? "not an epub".write(to: invalidURL, atomically: true, encoding: .utf8)

        let result = await PreviewContentLoader.loadEpub(from: invalidURL)
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure")
        }
        XCTAssertFalse(error.localizedDescription.isEmpty)
        XCTAssertNotEqual(error.localizedDescription, "error.epub.unzip_failed")
    }

    private func makeSampleEpub() throws -> URL {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-epub-build-\(UUID().uuidString)", isDirectory: true)
        createdURLs.append(workDir)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let containerDir = workDir.appendingPathComponent("META-INF", isDirectory: true)
        try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)

        try """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """.write(to: containerDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="book-id">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Test Book</dc:title>
            <dc:creator>Test Author</dc:creator>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
          </spine>
        </package>
        """.write(to: workDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter 1</title></head>
        <body><p>Hello EPUB</p></body>
        </html>
        """.write(to: workDir.appendingPathComponent("chapter1.xhtml"), atomically: true, encoding: .utf8)

        let mimetypeURL = workDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: mimetypeURL.path)

        let epubURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-sample-\(UUID().uuidString).epub")
        createdURLs.append(epubURL)

        let storeProcess = Process()
        storeProcess.currentDirectoryURL = workDir
        storeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        storeProcess.arguments = ["-X0", epubURL.path, "mimetype"]
        try storeProcess.run()
        storeProcess.waitUntilExit()
        XCTAssertEqual(storeProcess.terminationStatus, 0)

        let appendProcess = Process()
        appendProcess.currentDirectoryURL = workDir
        appendProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        appendProcess.arguments = ["-Xr9D", epubURL.path, "META-INF", "content.opf", "chapter1.xhtml"]
        try appendProcess.run()
        appendProcess.waitUntilExit()
        XCTAssertEqual(appendProcess.terminationStatus, 0)

        return epubURL
    }
}
