import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ClipboardFileCreation {
    enum TextFormat: Equatable {
        case markdown
        case plain
    }

    struct ImagePayload: Equatable {
        let data: Data
        let fileExtension: String
        /// PNG/TIFF 等需在写入前压缩；JPEG 等可直接落盘。
        let requiresCompression: Bool

        init(data: Data, fileExtension: String, requiresCompression: Bool = false) {
            self.data = data
            self.fileExtension = fileExtension
            self.requiresCompression = requiresCompression
        }
    }

    enum ContentKind: Equatable {
        case image(ImagePayload)
        case text(String, TextFormat)
    }

    static func contentKind(from pasteboard: NSPasteboard = .general) -> ContentKind? {
        if let imagePayload = imagePayload(from: pasteboard) {
            return .image(imagePayload)
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
        guard contentKind(from: pasteboard) != nil else { return false }
        return canCreateFile(in: directory, assumingContentAvailable: true)
    }

    static func canCreateFile(in directory: URL, assumingContentAvailable: Bool) -> Bool {
        guard assumingContentAvailable else { return false }
        guard !TrashLoader.isTrashPath(directory.path) else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return FileManager.default.isWritableFile(atPath: directory.path)
    }

    @discardableResult
    static func createFile(
        in directory: URL,
        pasteboard: NSPasteboard = .general
    ) -> URL? {
        guard let kind = contentKind(from: pasteboard) else { return nil }
        return writeFile(for: kind, in: directory, showErrors: true)
    }

    static func createFileAsync(
        in directory: URL,
        pasteboard: NSPasteboard = .general
    ) async -> URL? {
        guard let kind = contentKind(from: pasteboard) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            writeFile(for: kind, in: directory)
        }.value
    }

    private static func writeFile(for kind: ContentKind, in directory: URL, showErrors: Bool = false) -> URL? {
        let fileName: String
        let data: Data

        switch kind {
        case .image(let payload):
            let resolved: ImagePayload
            if payload.requiresCompression {
                resolved = normalizedCompressedPNG(from: payload.data)
                    ?? ImagePayload(data: payload.data, fileExtension: payload.fileExtension)
            } else {
                resolved = payload
            }
            fileName = suggestedImageFileName(fileExtension: resolved.fileExtension)
            data = resolved.data
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
            if showErrors {
                Task { @MainActor in
                    NSAlert(error: error).runModal()
                }
            }
            return nil
        }
    }

    static func presentCreateFileError(_ error: Error) {
        Task { @MainActor in
            NSAlert(error: error).runModal()
        }
    }

    static func presentCreateFileFailure() {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = L10n.Alert.operationFailed
            alert.informativeText = L10n.Alert.operationFailed
            alert.alertStyle = .warning
            alert.runModal()
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

    static func suggestedImageFileName(fileExtension: String) -> String {
        "\(L10n.File.pastedImageBaseName).\(fileExtension)"
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

    private static func imagePayload(from pasteboard: NSPasteboard) -> ImagePayload? {
        if let data = pasteboard.data(forType: .png) {
            return ImagePayload(data: data, fileExtension: "png", requiresCompression: true)
        }
        if let data = pasteboard.data(forType: .tiff) {
            return ImagePayload(data: data, fileExtension: "png", requiresCompression: true)
        }
        for candidate in preferredLossyImageTypes {
            if let data = pasteboard.data(forType: candidate.pasteboardType) {
                return ImagePayload(data: data, fileExtension: candidate.fileExtension)
            }
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation else { return nil }
        return ImagePayload(data: tiff, fileExtension: "png", requiresCompression: true)
    }

    /// 将剪贴板中的位图（截图常见 PNG/TIFF）统一转为压缩 PNG。
    private static func normalizedCompressedPNG(from imageData: Data) -> ImagePayload? {
        guard let compressed = compressToPNG(imageData) else {
            guard let bitmap = NSBitmapImageRep(data: imageData),
                  let png = bitmap.representation(using: .png, properties: [.interlaced: false]) else {
                return nil
            }
            return ImagePayload(data: png, fileExtension: "png")
        }
        return ImagePayload(data: compressed, fileExtension: "png")
    }

    private static func compressToPNG(_ imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let properties: [CFString: Any] = [
            kCGImageDestinationOptimizeColorForSharing: true,
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private static let preferredLossyImageTypes: [(pasteboardType: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpg"),
        (NSPasteboard.PasteboardType(UTType.heic.identifier), "heic"),
        (NSPasteboard.PasteboardType(UTType.gif.identifier), "gif"),
        (NSPasteboard.PasteboardType(UTType.bmp.identifier), "bmp"),
        (NSPasteboard.PasteboardType(UTType.webP.identifier), "webp"),
    ]
}
