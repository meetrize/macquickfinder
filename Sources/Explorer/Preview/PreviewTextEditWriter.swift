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
        try data.write(to: url, options: .atomic)
    }
}
