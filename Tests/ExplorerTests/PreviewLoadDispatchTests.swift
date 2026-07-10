import XCTest
@testable import Explorer

final class PreviewLoadDispatchTests: XCTestCase {
    private func input(
        ext: String,
        fileName: String? = nil,
        isHtmlFile: Bool = false,
        htmlPreviewMode: HtmlDisplayMode = .preview,
        overridingMode: CustomPreviewMode? = nil,
        supplementalMode: CustomPreviewMode? = nil
    ) -> PreviewLoadDispatchInput {
        PreviewLoadDispatchInput(
            pathExtension: ext,
            fileName: fileName ?? "file.\(ext)",
            isHtmlFile: isHtmlFile,
            htmlPreviewMode: htmlPreviewMode,
            overridingMode: overridingMode,
            supplementalMode: supplementalMode
        )
    }

    func testResolveBuiltInImagePDFAndMedia() {
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "png")), .builtInImage)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "svg")), .builtInImage)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "eps")), .builtInImage)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "pdf")), .builtInPDF)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "mp4")), .builtInMedia)
    }

    func testResolveBuiltInAudioExtensions() {
        for ext in ["mp3", "wav", "aac", "flac", "m4a"] {
            XCTAssertEqual(
                PreviewLoadDispatch.resolve(input(ext: ext)),
                .builtInMedia,
                "Expected built-in media route for .\(ext)"
            )
        }
    }

    func testResolveOfficeAndDocx() {
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "docx")), .docx)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "doc")), .doc)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "xlsx")), .xlsx)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "xls")), .xls)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "csv")), .csv)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "pptx")), .builtInOffice)
    }

    func testResolveArchiveByFileName() {
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "zip", fileName: "bundle.zip")),
            .archive
        )
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "tgz", fileName: "backup.tar.gz")),
            .archive
        )
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "rar", fileName: "backup.rar")),
            .archive
        )
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "7z", fileName: "backup.7z")),
            .archive
        )
    }

    func testResolveTextAndHtmlDeferredLoad() {
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "txt")),
            .builtInText(deferSourceLoad: false)
        )
        XCTAssertNotEqual(
            PreviewLoadDispatch.resolve(input(ext: "csv")),
            .builtInText(deferSourceLoad: false)
        )
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "html", isHtmlFile: true, htmlPreviewMode: .preview)),
            .builtInText(deferSourceLoad: true)
        )
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "html", isHtmlFile: true, htmlPreviewMode: .source)),
            .builtInText(deferSourceLoad: false)
        )
    }

    func testResolveTier1TextExtensions() {
        for ext in ["toml", "srt", "vtt", "gpx"] {
            XCTAssertEqual(
                PreviewLoadDispatch.resolve(input(ext: ext)),
                .builtInText(deferSourceLoad: false),
                "Expected built-in text route for .\(ext)"
            )
        }
    }

    func testResolveRTFUsesDedicatedRoute() {
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "rtf")), .rtf)
    }

    func testResolveEpubUsesDedicatedRoute() {
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "epub")), .epub)
    }

    func testResolveEmlUsesDedicatedRoute() {
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "eml")), .eml)
    }

    func testResolveFontUsesDedicatedRoute() {
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "ttf")), .font)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "otf")), .font)
    }

    func testOverrideRuleTakesPrecedenceOverBuiltIn() {
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "png", overridingMode: .text)),
            .customOverride(.text)
        )
    }

    func testSupplementalCustomRuleForUnknownExtension() {
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "proto", supplementalMode: .text)),
            .customSupplement(.text)
        )
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "proto")), .unavailable)
    }

    func testOverridePrecedesArchiveExtension() {
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(
                input(ext: "zip", fileName: "bundle.zip", overridingMode: .quickLook)
            ),
            .customOverride(.quickLook)
        )
    }
}
