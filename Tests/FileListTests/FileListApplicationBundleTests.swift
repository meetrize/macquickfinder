import XCTest
@testable import FileList

final class FileListApplicationBundleTests: XCTestCase {
    func testIsBundleRecognizesKnownPackageExtensions() {
        XCTAssertTrue(FileListApplicationBundle.isBundle(path: "/Applications/Safari.app"))
        XCTAssertTrue(FileListApplicationBundle.isBundle(path: "/tmp/Demo.APP"))
        XCTAssertTrue(FileListApplicationBundle.isBundle(path: "/tmp/Foo.framework"))
        XCTAssertTrue(FileListApplicationBundle.isBundle(path: "/tmp/Bar.bundle"))
        XCTAssertTrue(FileListApplicationBundle.isBundle(path: "/tmp/Doc.rtfd"))
        XCTAssertFalse(FileListApplicationBundle.isBundle(path: "/tmp/Notes"))
        XCTAssertFalse(FileListApplicationBundle.isBundle(path: "/tmp/photo.png"))
    }

    func testIsFavoriteableDirectoryRejectsMissingFilesAppsAndPlainFiles() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoriteableDir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let folder = tempRoot.appendingPathComponent("Project", isDirectory: true)
        let app = tempRoot.appendingPathComponent("Tool.app", isDirectory: true)
        let file = tempRoot.appendingPathComponent("a.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try "x".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertTrue(FileListApplicationBundle.isFavoriteableDirectory(path: folder.path))
        XCTAssertFalse(FileListApplicationBundle.isFavoriteableDirectory(path: app.path))
        XCTAssertFalse(FileListApplicationBundle.isFavoriteableDirectory(path: file.path))
        XCTAssertFalse(
            FileListApplicationBundle.isFavoriteableDirectory(
                path: tempRoot.appendingPathComponent("missing").path
            )
        )
    }
}
