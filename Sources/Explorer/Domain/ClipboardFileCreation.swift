import AppKit
import Foundation
import UniformTypeIdentifiers

enum ClipboardFileCreation {
    enum TextFormat: Equatable {
        case markdown
        case plain
    }

    enum ContentKind: Equatable {
        case image(Data)
        case text(String, TextFormat)
    }

    static func contentKind(from pasteboard: NSPasteboard = .general) -> ContentKind? {
        if let imageData = pngData(from: pasteboard) {
            return .image(imageData)
        }
        guard let text = pasteboard.string(forType: .string) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let format: TextFormat = isMarkdown(trimmed) ? .markdown : .plain
        return .text(text, format)
    }

    static func canCreateFile(
        in directory: URL,
        pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard !TrashLoader.isTrashPath(directory.path) else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        guard FileManager.default.isWritableFile(atPath: directory.path) else { return false }
        return contentKind(from: pasteboard) != nil
    }

    @discardableResult
    static func createFile(
        in directory: URL,
        pasteboard: NSPasteboard = .general
    ) -> URL? {
        guard let kind = contentKind(from: pasteboard) else { return nil }

        let fileName: String
        let data: Data

        switch kind {
        case .image(let pngData):
            fileName = L10n.File.pastedImageFileName
            data = pngData
        case .text(let text, let format):
            fileName = suggestedTextFileName(for: text, format: format)
            guard let encoded = text.data(using: .utf8) else { return nil }
            data = encoded
        }

        let fileURL = ArchiveOperations.uniqueNamedPath(name: fileName, in: directory)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    static func isMarkdown(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("---\n") || trimmed.hasPrefix("---\r\n") {
            return true
        }

        let lines = trimmed.components(separatedBy: .newlines)
        for line in lines.prefix(20) {
            let candidate = line.trimmingCharacters(in: .whitespaces)
            if candidate.isEmpty { continue }

            if candidate.range(of: #"^#{1,6}\s+\S"#, options: .regularExpression) != nil {
                return true
            }
            if candidate.hasPrefix("> ") {
                return true
            }
            if candidate.range(of: #"^[-*+]\s+\S"#, options: .regularExpression) != nil {
                return true
            }
            if candidate.range(of: #"^\d+\.\s+\S"#, options: .regularExpression) != nil {
                return true
            }
            if candidate.hasPrefix("```") {
                return true
            }
            if candidate.range(of: #"^[-*+]\s+\[[ xX]\]"#, options: .regularExpression) != nil {
                return true
            }
        }

        if trimmed.contains("```") { return true }
        if trimmed.range(of: #"\[.+?\]\(.+?\)"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"\*\*.+?\*\*"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"_.+?_"#, options: .regularExpression) != nil { return true }

        return false
    }

    static func suggestedTextFileName(for text: String, format: TextFormat) -> String {
        let ext = format == .markdown ? "md" : "txt"
        if let base = titleBase(from: text), !base.isEmpty {
            return "\(base).\(ext)"
        }
        switch format {
        case .markdown:
            return L10n.File.pastedMarkdownFileName
        case .plain:
            return L10n.File.pastedTextFileName
        }
    }

    static func titleBase(from text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            var candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.isEmpty { continue }

            candidate = candidate.replacingOccurrences(
                of: #"^#{1,6}\s+"#,
                with: "",
                options: .regularExpression
            )
            candidate = candidate.replacingOccurrences(
                of: #"^[-*+]\s+"#,
                with: "",
                options: .regularExpression
            )
            candidate = candidate.replacingOccurrences(
                of: #"^\d+\.\s+"#,
                with: "",
                options: .regularExpression
            )
            candidate = candidate.replacingOccurrences(
                of: #"^>\s+"#,
                with: "",
                options: .regularExpression
            )
            candidate = candidate.replacingOccurrences(
                of: #"^[-*+]\s+\[[ xX]\]\s+"#,
                with: "",
                options: .regularExpression
            )

            let sanitized = sanitizeFilenameBase(candidate)
            if !sanitized.isEmpty {
                return sanitized
            }
        }
        return nil
    }

    static func sanitizeFilenameBase(_ raw: String, maxLength: Int = 40) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        result = String(result.unicodeScalars.filter { !invalidCharacters.contains($0) })
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return "" }
        if result.count > maxLength {
            result = String(result.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) {
            return png
        }
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }
}
