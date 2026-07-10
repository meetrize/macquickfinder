import XCTest
@testable import Explorer

final class ArchivePreviewLoaderTests: XCTestCase {
    func testDecodeTarEscapedPathChinese() {
        let escaped = #"\345\237\272\344\272\216\345\210\206\345\261\202\345\216\213\347\274\251"#
        XCTAssertEqual(
            ArchivePreviewLoader.decodeTarEscapedPath(escaped),
            "基于分层压缩"
        )
    }

    func testDecodeTarEscapedPathLeavesPlainPathUntouched() {
        let plain = "基于分层压缩/001_权利要求书.md"
        XCTAssertEqual(ArchivePreviewLoader.decodeTarEscapedPath(plain), plain)
    }

    func testParseTarVerboseListingLineChinesePath() {
        let line = "-rw-r--r--  0 501    0           6 Jun 23 14:10 中文目录/测试文件.txt"
        let entry = ArchivePreviewLoader.parseTarVerboseListingLine(line)
        XCTAssertEqual(entry?.path, "中文目录/测试文件.txt")
        XCTAssertEqual(entry?.isDirectory, false)
        XCTAssertEqual(entry?.size, 6)
    }

    func testParseTarVerboseListingLineOctalEscapedPath() {
        let line = #"-rw-------  0 0      0          13 Jan  1  1980 \345\237\272\344\272\216/001_\346\235\203\345\210\251.md"#
        let entry = ArchivePreviewLoader.parseTarVerboseListingLine(line)
        XCTAssertEqual(entry?.path, "基于/001_权利.md")
        XCTAssertEqual(entry?.size, 13)
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

    func testListingEntryLimits() {
        XCTAssertEqual(ArchivePreviewLoader.summaryMaxEntries, 200)
        XCTAssertEqual(ArchivePreviewLoader.verboseMaxEntries, 1_000)
    }

    func testArchiveKindDetection() {
        XCTAssertEqual(ArchivePreviewLoader.ArchiveKind.from(fileName: "bundle.zip"), .zip)
        XCTAssertEqual(ArchivePreviewLoader.ArchiveKind.from(fileName: "backup.tar.gz"), .tar)
        XCTAssertEqual(ArchivePreviewLoader.ArchiveKind.from(fileName: "game.7z"), .sevenZip)
        XCTAssertEqual(ArchivePreviewLoader.ArchiveKind.from(fileName: "win.rar"), .rar)
        XCTAssertNil(ArchivePreviewLoader.ArchiveKind.from(fileName: "notes.txt"))
    }

    func testIsArchiveFileNameIncludesRarAndSevenZip() {
        XCTAssertTrue(ArchivePreviewLoader.isArchiveFileName("archive.rar"))
        XCTAssertTrue(ArchivePreviewLoader.isArchiveFileName("archive.7z"))
        XCTAssertTrue(ArchivePreviewLoader.isArchiveFileName("bundle.zip"))
    }

    func testParseSevenZipSLTOutput() {
        let output = """
        Path = folder/
        Attributes = D....
        Size =
        
        Path = folder/readme.txt
        Attributes = ....A
        Size = 13
        """
        let entries = ArchiveAlternateListing.parseSevenZipSLT(output)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].path, "folder/")
        XCTAssertTrue(entries[0].isDirectory)
        XCTAssertEqual(entries[1].path, "folder/readme.txt")
        XCTAssertEqual(entries[1].size, 13)
    }

    func testParseLSARJSONOutput() {
        let json = """
        {
          "lsarContents": [
            { "XADFileName": "docs/", "XADIsDirectory": true },
            { "XADFileName": "docs/readme.txt", "XADIsDirectory": false, "XADFileSize": 42 }
          ]
        }
        """
        let entries = try? ArchiveAlternateListing.parseLSARJSON(json)
        XCTAssertEqual(entries?.count, 2)
        XCTAssertEqual(entries?.first?.path, "docs/")
        XCTAssertEqual(entries?.last?.path, "docs/readme.txt")
        XCTAssertEqual(entries?.last?.size, 42)
    }
}
