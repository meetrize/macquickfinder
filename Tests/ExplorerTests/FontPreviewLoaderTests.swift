import XCTest
@testable import Explorer

final class FontPreviewLoaderTests: XCTestCase {
    func testLoadSystemFontMetadata() throws {
        let url = try resolveSampleFontURL()
        try XCTSkipIf(url == nil, "No sample TTF/OTF found on this system")

        let content = try FontPreviewLoader.load(from: url!)
        XCTAssertFalse(content.metadata.fullName.isEmpty)
        XCTAssertFalse(content.metadata.familyName.isEmpty)
        XCTAssertFalse(content.postScriptName.isEmpty)
        XCTAssertGreaterThan(content.metadata.glyphCount, 0)
    }

    func testLoadFontViaPreviewContentLoader() async throws {
        let url = try resolveSampleFontURL()
        try XCTSkipIf(url == nil, "No sample TTF/OTF found on this system")

        let result = await PreviewContentLoader.loadFont(from: url!)
        guard case .success(let content) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertFalse(content.metadata.fullName.isEmpty)
    }

    func testMakePreviewFontAfterRegistration() throws {
        let url = try resolveSampleFontURL()
        try XCTSkipIf(url == nil, "No sample TTF/OTF found on this system")

        XCTAssertTrue(FontPreviewLoader.ensureFontRegistered(at: url!))
        let font = FontPreviewLoader.makePreviewFont(from: url!, size: 24)
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, 24, accuracy: 0.1)
        FontPreviewLoader.unregisterFontForPreview(at: url!)
    }

    private func resolveSampleFontURL() throws -> URL? {
        let candidates = [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
            "/Library/Fonts/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            guard ext == "ttf" || ext == "otf" else { continue }
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
