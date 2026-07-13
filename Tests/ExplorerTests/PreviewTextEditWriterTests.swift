import XCTest
@testable import Explorer

final class PreviewTextEditWriterTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewTextEditWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
    }

    func testWritePersistsUTF8Content() throws {
        let url = tempDirectory.appendingPathComponent("sample.txt")
        try Data("seed".utf8).write(to: url)

        try PreviewTextEditWriter.write("hello\nworld", to: url)

        let saved = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(saved, "hello\nworld")
    }

    func testWriteReplacesExistingContentInPlace() throws {
        let url = tempDirectory.appendingPathComponent("inplace.txt")
        try Data("before".utf8).write(to: url)

        try PreviewTextEditWriter.write("after", to: url)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "after")
    }

    func testWriteRejectsNonWritableFile() throws {
        let url = tempDirectory.appendingPathComponent("readonly.txt")
        try Data("seed".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)

        XCTAssertThrowsError(try PreviewTextEditWriter.write("changed", to: url)) { error in
            XCTAssertEqual(error as? PreviewTextEditError, .notWritable)
        }
    }
}
