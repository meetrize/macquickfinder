import Foundation

enum PreviewTextEditError: Error, Equatable {
    case notUTF8Encodable
    case notWritable
}

enum PreviewTextEditWriter {
    static func write(_ text: String, to url: URL) throws {
        guard FileManager.default.isWritableFile(atPath: url.path) else {
            throw PreviewTextEditError.notWritable
        }
        guard let data = text.data(using: .utf8) else {
            throw PreviewTextEditError.notUTF8Encodable
        }
        // 原地写入，避免 `.atomic` 替换触发 FSEvents rename 导致目录全量 reload。
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }
}
