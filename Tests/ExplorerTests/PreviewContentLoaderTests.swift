import XCTest
@testable import Explorer

final class PreviewContentLoaderTests: XCTestCase {
    func testLoadRTFRichTextFromValidDocument() async throws {
        let rtf = #"{\rtf1\ansi\deff0 {\fonttbl {\f0 Helvetica;}} \f0\fs24 Hello RTF}"#
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-preview-\(UUID().uuidString).rtf")
        defer { try? FileManager.default.removeItem(at: url) }

        try rtf.write(to: url, atomically: true, encoding: .utf8)

        let richText = await PreviewContentLoader.loadRTFRichText(from: url)
        XCTAssertNotNil(richText)
        XCTAssertTrue(richText?.string.contains("Hello RTF") == true)
    }

    func testLoadRTFRichTextReturnsNilForInvalidData() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-preview-\(UUID().uuidString).rtf")
        defer { try? FileManager.default.removeItem(at: url) }

        try? "not rtf".write(to: url, atomically: true, encoding: .utf8)

        let richText = await PreviewContentLoader.loadRTFRichText(from: url)
        XCTAssertNil(richText)
    }
}
