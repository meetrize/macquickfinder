import XCTest
@testable import Explorer

final class SnippetImportExportTests: XCTestCase {
    func testParseImportBundleWithReferenceDateTimestamps() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/snippets-batch-file-ops.json")

        let items = try SnippetImportExport.parseImportItems(from: url, existing: [])
        XCTAssertEqual(items.count, 18)
        XCTAssertEqual(items.first?.snippet.name, "顺序编号改名")
    }

    func testParseImportBundleWithISO8601Dates() throws {
        let json = """
        {
          "schemaVersion": 1,
          "exportedAt": "2026-07-01T08:00:00Z",
          "app": "MeoFind",
          "kind": "snippet-bundle",
          "snippets": [{
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "测试",
            "scriptType": "shell",
            "scope": { "kind": "anytime" },
            "content": "echo ok",
            "variableHints": [],
            "sortOrder": 0,
            "executionCount": 0,
            "createdAt": "2026-07-01T08:00:00Z",
            "updatedAt": "2026-07-01T08:00:00Z",
            "isBuiltin": false,
            "useSystemTerminal": false
          }]
        }
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let items = try SnippetImportExport.parseImportItems(from: url, existing: [])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].snippet.name, "测试")
    }
}
