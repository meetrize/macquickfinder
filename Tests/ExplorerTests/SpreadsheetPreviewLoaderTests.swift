import XCTest
@testable import Explorer

final class SpreadsheetPreviewLoaderTests: XCTestCase {
    func testLoadXLSXTextExtractsSharedStrings() throws {
        let url = try makeTemporaryXLSX()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let text = try SpreadsheetPreviewLoader.loadText(from: url)
        XCTAssertTrue(text.contains("=== Sheet1 ==="))
        XCTAssertTrue(text.contains("Hello"))
        XCTAssertTrue(text.contains("World"))
    }

    private func makeTemporaryXLSX() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-test-xlsx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("sample.xlsx")

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """
        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
        """
        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """
        let sharedStrings = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="2" uniqueCount="2">
        <si><t>Hello</t></si><si><t>World</t></si>
        </sst>
        """
        let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
        <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
        </sheetData></worksheet>
        """

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: dir.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: dir.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: dir.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)

        try contentTypes.write(to: dir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try rels.write(to: dir.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
        try workbook.write(to: dir.appendingPathComponent("xl/workbook.xml"), atomically: true, encoding: .utf8)
        try workbookRels.write(to: dir.appendingPathComponent("xl/_rels/workbook.xml.rels"), atomically: true, encoding: .utf8)
        try sharedStrings.write(to: dir.appendingPathComponent("xl/sharedStrings.xml"), atomically: true, encoding: .utf8)
        try sheet.write(to: dir.appendingPathComponent("xl/worksheets/sheet1.xml"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = dir
        process.arguments = ["-qr", url.path, "."]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        return url
    }
}
