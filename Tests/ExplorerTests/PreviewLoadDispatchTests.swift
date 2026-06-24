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
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "pdf")), .builtInPDF)
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "mp4")), .builtInMedia)
    }

    func testResolveOfficeAndDocx() {
        XCTAssertEqual(PreviewLoadDispatch.resolve(input(ext: "docx")), .docx)
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
    }

    func testResolveTextAndHtmlDeferredLoad() {
        XCTAssertEqual(
            PreviewLoadDispatch.resolve(input(ext: "txt")),
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
