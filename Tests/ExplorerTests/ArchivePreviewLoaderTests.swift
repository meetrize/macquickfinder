import XCTest
@testable import Explorer

final class ArchivePreviewLoaderTests: XCTestCase {
    func testParseTarVerboseListingLineChinesePath() {
        let line = "-rw-r--r--  0 501    0           6 Jun 23 14:10 中文目录/测试文件.txt"
        let entry = ArchivePreviewLoader.parseTarVerboseListingLine(line)
        XCTAssertEqual(entry?.path, "中文目录/测试文件.txt")
        XCTAssertEqual(entry?.isDirectory, false)
        XCTAssertEqual(entry?.size, 6)
    }

    func testParseTarVerboseListingLineDirectory() {
        let line = "drwxr-xr-x  0 501    0           0 Jun 23 14:10 中文目录/"
        let entry = ArchivePreviewLoader.parseTarVerboseListingLine(line)
        XCTAssertEqual(entry?.path, "中文目录/")
        XCTAssertEqual(entry?.isDirectory, true)
        XCTAssertNil(entry?.size)
    }

    func testParseTarVerboseListingLinePathWithSpaces() {
        let line = "-rw-r--r--  0 501    0           2 Jun 23 14:10 a b/文件 名.txt"
        let entry = ArchivePreviewLoader.parseTarVerboseListingLine(line)
        XCTAssertEqual(entry?.path, "a b/文件 名.txt")
        XCTAssertEqual(entry?.size, 2)
    }

    func testParseTarVerboseListingLineIgnoresHeader() {
        XCTAssertNil(ArchivePreviewLoader.parseTarVerboseListingLine("total 12"))
    }
}
