import XCTest
@testable import Explorer

final class EmlPreviewLoaderTests: XCTestCase {
    private var createdURLs: [URL] = []

    override func tearDown() {
        for url in createdURLs {
            try? FileManager.default.removeItem(at: url)
        }
        createdURLs.removeAll()
        super.tearDown()
    }

    func testLoadPlainTextEmail() throws {
        let url = try writeEmail(
            """
            From: sender@example.com
            To: recipient@example.com
            Subject: Plain Subject
            Date: Mon, 01 Jan 2024 12:00:00 +0000
            Content-Type: text/plain; charset="UTF-8"

            Hello plain body
            """
        )

        let content = try EmlPreviewLoader.load(from: url)
        XCTAssertEqual(content.headers.from, "sender@example.com")
        XCTAssertEqual(content.headers.to, "recipient@example.com")
        XCTAssertEqual(content.headers.subject, "Plain Subject")
        XCTAssertEqual(content.plainBody, "Hello plain body")
        XCTAssertNil(content.htmlBody)
        XCTAssertTrue(content.attachments.isEmpty)
    }

    func testLoadMultipartAlternativePrefersHTML() throws {
        let url = try writeEmail(
            """
            From: html@example.com
            To: user@example.com
            Subject: HTML Mail
            MIME-Version: 1.0
            Content-Type: multipart/alternative; boundary="boundary42"

            --boundary42
            Content-Type: text/plain; charset="UTF-8"

            Plain fallback
            --boundary42
            Content-Type: text/html; charset="UTF-8"

            <p>HTML <strong>body</strong></p>
            --boundary42--
            """
        )

        let content = try EmlPreviewLoader.load(from: url)
        XCTAssertEqual(content.plainBody, "Plain fallback")
        XCTAssertEqual(content.htmlBody, "<p>HTML <strong>body</strong></p>")
    }

    func testLoadMultipartMixedListsAttachment() throws {
        let url = try writeEmail(
            """
            From: files@example.com
            To: user@example.com
            Subject: With Attachment
            MIME-Version: 1.0
            Content-Type: multipart/mixed; boundary="mixed99"

            --mixed99
            Content-Type: text/plain; charset="UTF-8"

            See attached file.
            --mixed99
            Content-Type: application/pdf
            Content-Disposition: attachment; filename="report.pdf"
            Content-Transfer-Encoding: base64

            UG9saXNoZWQ=
            --mixed99--
            """
        )

        let content = try EmlPreviewLoader.load(from: url)
        XCTAssertEqual(content.plainBody, "See attached file.")
        XCTAssertEqual(content.attachments.count, 1)
        XCTAssertEqual(content.attachments[0].fileName, "report.pdf")
        XCTAssertGreaterThan(content.attachments[0].size, 0)
    }

    func testLoadEmlViaPreviewContentLoader() async throws {
        let url = try writeEmail(
            """
            From: async@example.com
            To: user@example.com
            Subject: Async
            Content-Type: text/plain; charset="UTF-8"

            Async body
            """
        )

        let result = await PreviewContentLoader.loadEml(from: url)
        guard case .success(let content) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(content.headers.subject, "Async")
        XCTAssertEqual(content.plainBody, "Async body")
    }

    private func writeEmail(_ raw: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-mail-\(UUID().uuidString).eml")
        createdURLs.append(url)
        try raw.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
