import AppKit
import Foundation

/// 使用 macOS 内置 Office 导入（与 TextEdit 相同）加载 docx 为富文本。
enum OfficeDocumentPreviewLoader {
    static func loadDOCX(from url: URL) throws -> NSAttributedString {
        do {
            return try loadOfficeOpenXML(from: url)
        } catch {
            return try loadViaTextUtil(from: url)
        }
    }

    /// 后台线程加载 docx 并导出 RTF `Data`，便于跨并发边界传递。
    static func loadDOCXRTFData(from url: URL) throws -> Data {
        let attributed = try loadDOCX(from: url)
        let data = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        guard !data.isEmpty else {
            throw LoaderError.emptyDocument
        }
        return data
    }

    private static func loadOfficeOpenXML(from url: URL) throws -> NSAttributedString {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        var documentAttributes: NSDictionary?
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.officeOpenXML,
        ]
        let attributed = try NSAttributedString(
            data: data,
            options: options,
            documentAttributes: &documentAttributes
        )
        guard attributed.length > 0 else {
            throw LoaderError.emptyDocument
        }
        return attributed
    }

    private static func loadViaTextUtil(from url: URL) throws -> NSAttributedString {
        let rtfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-docx-\(UUID().uuidString).rtf")
        defer { try? FileManager.default.removeItem(at: rtfURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", "rtf", "-output", rtfURL.path, url.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LoaderError.textUtilFailed(code: process.terminationStatus)
        }

        let data = try Data(contentsOf: rtfURL)
        let attributed = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        guard attributed.length > 0 else {
            throw LoaderError.emptyDocument
        }
        return attributed
    }

    enum LoaderError: Error {
        case emptyDocument
        case textUtilFailed(code: Int32)
    }
}
