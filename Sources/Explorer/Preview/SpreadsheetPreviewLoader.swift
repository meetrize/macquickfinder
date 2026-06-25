import Foundation

/// 将 xlsx / xls 转为可选中的纯文本表格预览。
enum SpreadsheetPreviewLoader {
    private static let maxSheets = 20
    private static let maxRowsPerSheet = 5_000
    private static let maxColumnsPerRow = 200

    static func loadText(from url: URL) throws -> String {
        switch url.pathExtension.lowercased() {
        case "xlsx":
            return try loadXLSXText(from: url)
        case "xls":
            return try loadViaTextUtil(from: url)
        default:
            throw LoaderError.unsupportedFormat
        }
    }

    private static func loadXLSXText(from url: URL) throws -> String {
        let extracted = try unzipToTemporaryDirectory(url: url)
        defer { try? FileManager.default.removeItem(at: extracted) }

        let sharedStrings = try parseSharedStrings(
            at: extracted.appendingPathComponent("xl/sharedStrings.xml")
        )
        let sheetFiles = try resolveWorksheetURLs(in: extracted)
        guard !sheetFiles.isEmpty else {
            throw LoaderError.emptyDocument
        }

        var sections: [String] = []
        sections.reserveCapacity(sheetFiles.count)
        for (sheetName, sheetURL) in sheetFiles.prefix(maxSheets) {
            let rows = try parseWorksheet(at: sheetURL, sharedStrings: sharedStrings)
            guard !rows.isEmpty else { continue }
            var block = "=== \(sheetName) ===\n"
            block += rows.joined(separator: "\n")
            sections.append(block)
        }

        let text = sections.joined(separator: "\n\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LoaderError.emptyDocument
        }
        return text
    }

    private static func loadViaTextUtil(from url: URL) throws -> String {
        let txtURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-xls-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: txtURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", "txt", "-output", txtURL.path, url.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoaderError.textUtilFailed(code: process.terminationStatus)
        }

        let text = try String(contentsOf: txtURL, encoding: .utf8)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LoaderError.emptyDocument
        }
        return text
    }

    private static func unzipToTemporaryDirectory(url: URL) throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-xlsx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", url.path, "-d", dest.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoaderError.unzipFailed(code: process.terminationStatus)
        }
        return dest
    }

    private static func resolveWorksheetURLs(in root: URL) throws -> [(name: String, url: URL)] {
        let workbookURL = root.appendingPathComponent("xl/workbook.xml")
        let names = try parseWorkbookSheetNames(at: workbookURL)
        let worksheetDir = root.appendingPathComponent("xl/worksheets")
        let files = try FileManager.default.contentsOfDirectory(
            at: worksheetDir,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "xml" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if names.count == files.count, !names.isEmpty {
            return zip(names, files).map { ($0, $1) }
        }
        return files.enumerated().map { index, file in
            ("Sheet\(index + 1)", file)
        }
    }

    private static func parseWorkbookSheetNames(at url: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let parser = WorkbookSheetNameParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return [] }
        return parser.sheetNames
    }

    private static func parseSharedStrings(at url: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let parser = SharedStringsParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return [] }
        return parser.strings
    }

    private static func parseWorksheet(at url: URL, sharedStrings: [String]) throws -> [String] {
        let data = try Data(contentsOf: url)
        let parser = WorksheetParser(sharedStrings: sharedStrings)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return [] }
        return parser.formattedRows(
            maxRows: maxRowsPerSheet,
            maxColumns: maxColumnsPerRow
        )
    }

    enum LoaderError: Error {
        case unsupportedFormat
        case emptyDocument
        case unzipFailed(code: Int32)
        case textUtilFailed(code: Int32)
    }
}

// MARK: - XML parsers

private final class WorkbookSheetNameParser: NSObject, XMLParserDelegate {
    var sheetNames: [String] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.hasSuffix("sheet"), let name = attributeDict["name"] else { return }
        sheetNames.append(name)
    }
}

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var capturesText = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName.hasSuffix("t") {
            capturesText = true
            current = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturesText {
            current += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName.hasSuffix("t") {
            capturesText = false
        }
        if elementName.hasSuffix("si") {
            strings.append(current)
            current = ""
        }
    }
}

private final class WorksheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var rows: [Int: [Int: String]] = [:]
    private var currentRow = 0
    private var currentColumn = 0
    private var currentType: String?
    private var valueText = ""
    private var inlineText = ""
    private var capturesValue = false
    private var capturesInline = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func formattedRows(maxRows: Int, maxColumns: Int) -> [String] {
        rows.keys.sorted().prefix(maxRows).compactMap { rowIndex in
            guard let columns = rows[rowIndex], !columns.isEmpty else { return nil }
            let maxCol = min(columns.keys.max() ?? 0, maxColumns)
            return (1...maxCol).map { columns[$0] ?? "" }.joined(separator: "\t")
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName.hasSuffix("row"), let ref = attributeDict["r"], let row = Int(ref) {
            currentRow = row
        } else if elementName.hasSuffix("c") {
            if let ref = attributeDict["r"], let parsed = CellReference.parse(ref) {
                currentRow = parsed.row
                currentColumn = parsed.column
            }
            currentType = attributeDict["t"]
            valueText = ""
            inlineText = ""
        } else if elementName.hasSuffix("v") {
            capturesValue = true
            valueText = ""
        } else if elementName.hasSuffix("t") {
            capturesInline = true
            inlineText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturesValue {
            valueText += string
        }
        if capturesInline {
            inlineText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName.hasSuffix("v") {
            capturesValue = false
        }
        if elementName.hasSuffix("t") {
            capturesInline = false
        }
        if elementName.hasSuffix("c") {
            let resolved = resolveCellValue()
            guard !resolved.isEmpty else { return }
            var row = rows[currentRow, default: [:]]
            row[currentColumn] = resolved
            rows[currentRow] = row
        }
    }

    private func resolveCellValue() -> String {
        if currentType == "inlineStr" {
            return inlineText
        }
        let raw = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        if currentType == "s", let index = Int(raw), index >= 0, index < sharedStrings.count {
            return sharedStrings[index]
        }
        return raw
    }
}

private enum CellReference {
    static func parse(_ ref: String) -> (column: Int, row: Int)? {
        let upper = ref.uppercased()
        var columnLetters = ""
        var rowDigits = ""
        for scalar in upper.unicodeScalars {
            if CharacterSet.uppercaseLetters.contains(scalar) {
                if !rowDigits.isEmpty { return nil }
                columnLetters.unicodeScalars.append(scalar)
            } else if CharacterSet.decimalDigits.contains(scalar) {
                rowDigits.unicodeScalars.append(scalar)
            } else {
                return nil
            }
        }
        guard let row = Int(rowDigits), row > 0, !columnLetters.isEmpty else { return nil }
        return (columnIndex(from: columnLetters), row)
    }

    private static func columnIndex(from letters: String) -> Int {
        var index = 0
        for scalar in letters.unicodeScalars {
            index = index * 26 + Int(scalar.value - 64)
        }
        return index
    }
}
