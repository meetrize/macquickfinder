import CoreFoundation
import Foundation

struct EmlPreviewHeaders: Equatable {
    let from: String?
    let to: String?
    let cc: String?
    let subject: String?
    let date: String?
}

struct EmlAttachmentPreview: Identifiable, Equatable {
    let id: String
    let fileName: String
    let size: Int
}

struct EmlPreviewContent: Equatable {
    let headers: EmlPreviewHeaders
    let plainBody: String?
    let htmlBody: String?
    let attachments: [EmlAttachmentPreview]
}

/// 解析 `.eml` MIME 邮件，提取头部、正文与附件列表（不预览附件内容）。
enum EmlPreviewLoader {
    static let maxBodyBytes = 5 * 1024 * 1024

    static func load(from url: URL) throws -> EmlPreviewContent {
        var data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard !data.isEmpty else { throw LoaderError.emptyMessage }
        if data.count > maxBodyBytes {
            data = data.prefix(maxBodyBytes)
        }

        let raw = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        guard !raw.isEmpty else { throw LoaderError.unreadableEncoding }

        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        guard let separatorRange = normalized.range(of: "\n\n") else {
            throw LoaderError.invalidFormat
        }

        let headerBlock = String(normalized[..<separatorRange.lowerBound])
        let bodyBlock = String(normalized[separatorRange.upperBound...])
        let headers = parseHeaderBlock(headerBlock)

        var plainBody: String?
        var htmlBody: String?
        var attachments: [EmlAttachmentPreview] = []

        if let contentType = headers["content-type"], contentType.lowercased().contains("multipart/") {
            let boundary = extractBoundary(from: contentType)
            guard let boundary, !boundary.isEmpty else { throw LoaderError.invalidFormat }
            let parts = splitMultipart(bodyBlock, boundary: boundary)
            collectBodiesAndAttachments(
                from: parts,
                plainBody: &plainBody,
                htmlBody: &htmlBody,
                attachments: &attachments
            )
        } else {
            let encoding = headers["content-transfer-encoding"]
            let charset = extractCharset(from: headers["content-type"])
            let decoded = decodeBody(bodyBlock, encoding: encoding, charset: charset)
            assignBody(
                decoded,
                contentType: headers["content-type"],
                disposition: headers["content-disposition"],
                fileName: extractFileName(from: headers["content-disposition"]),
                plainBody: &plainBody,
                htmlBody: &htmlBody,
                attachments: &attachments
            )
        }

        guard plainBody != nil || htmlBody != nil || !attachments.isEmpty else {
            throw LoaderError.emptyBody
        }

        return EmlPreviewContent(
            headers: EmlPreviewHeaders(
                from: decodedHeaderValue(headers["from"]),
                to: decodedHeaderValue(headers["to"]),
                cc: decodedHeaderValue(headers["cc"]),
                subject: decodedHeaderValue(headers["subject"]),
                date: decodedHeaderValue(headers["date"])
            ),
            plainBody: plainBody,
            htmlBody: htmlBody,
            attachments: attachments
        )
    }

    private static func parseHeaderBlock(_ block: String) -> [String: String] {
        var unfolded: [String] = []
        for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.first == " " || line.first == "\t", let last = unfolded.last {
                unfolded[unfolded.count - 1] = last + " " + line.trimmingCharacters(in: .whitespaces)
            } else {
                unfolded.append(String(line))
            }
        }

        var headers: [String: String] = [:]
        for line in unfolded {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !value.isEmpty else { continue }
            if let existing = headers[name] {
                headers[name] = existing + ", " + value
            } else {
                headers[name] = value
            }
        }
        return headers
    }

    private static func splitMultipart(_ body: String, boundary: String) -> [MimePart] {
        let delimiter = "--\(boundary)"
        let segments = body.components(separatedBy: delimiter)
        var parts: [MimePart] = []
        parts.reserveCapacity(segments.count)

        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "--" { continue }
            guard let separator = trimmed.range(of: "\n\n") else { continue }
            let headerBlock = String(trimmed[..<separator.lowerBound])
            let partBody = String(trimmed[separator.upperBound...])
            parts.append(MimePart(headers: parseHeaderBlock(headerBlock), body: partBody))
        }
        return parts
    }

    private static func collectBodiesAndAttachments(
        from parts: [MimePart],
        plainBody: inout String?,
        htmlBody: inout String?,
        attachments: inout [EmlAttachmentPreview]
    ) {
        for part in parts {
            let contentType = part.headers["content-type"] ?? ""
            if contentType.lowercased().contains("multipart/") {
                let boundary = extractBoundary(from: contentType)
                if let boundary, !boundary.isEmpty {
                    let nested = splitMultipart(part.body, boundary: boundary)
                    collectBodiesAndAttachments(
                        from: nested,
                        plainBody: &plainBody,
                        htmlBody: &htmlBody,
                        attachments: &attachments
                    )
                }
                continue
            }

            let encoding = part.headers["content-transfer-encoding"]
            let charset = extractCharset(from: contentType)
            let decoded = decodeBody(part.body, encoding: encoding, charset: charset)
            assignBody(
                decoded,
                contentType: contentType,
                disposition: part.headers["content-disposition"],
                fileName: extractFileName(from: part.headers["content-disposition"]),
                plainBody: &plainBody,
                htmlBody: &htmlBody,
                attachments: &attachments
            )
        }
    }

    private static func assignBody(
        _ decoded: String,
        contentType: String?,
        disposition: String?,
        fileName: String?,
        plainBody: inout String?,
        htmlBody: inout String?,
        attachments: inout [EmlAttachmentPreview]
    ) {
        let lowerType = contentType?.lowercased() ?? ""
        let lowerDisposition = disposition?.lowercased() ?? ""
        let isAttachment = lowerDisposition.contains("attachment")
            || (
                fileName != nil
                    && !lowerType.contains("text/plain")
                    && !lowerType.contains("text/html")
            )

        if isAttachment {
            let name = fileName ?? "attachment"
            attachments.append(
                EmlAttachmentPreview(
                    id: "\(name)-\(attachments.count)",
                    fileName: name,
                    size: decoded.utf8.count
                )
            )
            return
        }

        if lowerType.contains("text/html"), htmlBody == nil {
            htmlBody = decoded
        } else if lowerType.contains("text/plain"), plainBody == nil {
            plainBody = decoded
        } else if htmlBody == nil, plainBody == nil, lowerDisposition.contains("inline") {
            if lowerType.contains("html") {
                htmlBody = decoded
            } else {
                plainBody = decoded
            }
        }
    }

    private static func decodeBody(_ body: String, encoding: String?, charset: String?) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lowerEncoding = encoding?.lowercased() ?? "7bit"
        let decodedData: Data?
        switch lowerEncoding {
        case "base64":
            let sanitized = trimmed.replacingOccurrences(of: "\n", with: "")
            decodedData = Data(base64Encoded: sanitized, options: .ignoreUnknownCharacters)
        case "quoted-printable":
            decodedData = decodeQuotedPrintable(trimmed)
        default:
            decodedData = trimmed.data(using: .utf8) ?? trimmed.data(using: .isoLatin1)
        }

        guard let decodedData else { return trimmed }
        if let charset, let encoding = charsetEncoding(charset) {
            return String(data: decodedData, encoding: encoding) ?? String(decoding: decodedData, as: UTF8.self)
        }
        return String(data: decodedData, encoding: .utf8)
            ?? String(data: decodedData, encoding: .isoLatin1)
            ?? trimmed
    }

    private static func decodeQuotedPrintable(_ input: String) -> Data? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(input.utf8.count)
        let scalars = Array(input.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "=" {
                if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    index += 2
                    continue
                }
                if index + 2 < scalars.count {
                    let hex = String(scalars[index + 1]) + String(scalars[index + 2])
                    if let value = UInt8(hex, radix: 16) {
                        bytes.append(value)
                        index += 3
                        continue
                    }
                }
            }
            if scalar == "\r" {
                index += 1
                continue
            }
            guard scalar.value <= 255 else {
                index += 1
                continue
            }
            bytes.append(UInt8(truncatingIfNeeded: scalar.value))
            index += 1
        }
        return Data(bytes)
    }

    private static func extractBoundary(from contentType: String) -> String? {
        let parts = contentType.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts where part.lowercased().hasPrefix("boundary=") {
            var value = String(part.dropFirst("boundary=".count))
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }
            return value
        }
        return nil
    }

    private static func extractCharset(from contentType: String?) -> String? {
        guard let contentType else { return nil }
        for part in contentType.split(separator: ";") {
            let token = part.trimmingCharacters(in: .whitespaces).lowercased()
            if token.hasPrefix("charset=") {
                var value = String(token.dropFirst("charset=".count))
                if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                    value.removeFirst()
                    value.removeLast()
                }
                return value
            }
        }
        return nil
    }

    private static func extractFileName(from disposition: String?) -> String? {
        guard let disposition else { return nil }
        let parts = disposition.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts {
            let lower = part.lowercased()
            if lower.hasPrefix("filename*=") {
                let raw = String(part.dropFirst("filename*=".count))
                if let encoded = raw.split(separator: "'", omittingEmptySubsequences: false).last {
                    return decodedHeaderValue(String(encoded))
                }
            }
            if lower.hasPrefix("filename=") {
                var value = String(part.dropFirst("filename=".count))
                if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                    value.removeFirst()
                    value.removeLast()
                }
                return decodedHeaderValue(value)
            }
        }
        return nil
    }

    private static func charsetEncoding(_ charset: String) -> String.Encoding? {
        switch charset.lowercased() {
        case "utf-8", "utf8":
            return .utf8
        case "iso-8859-1", "latin1", "windows-1252":
            return .isoLatin1
        default:
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
            guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        }
    }

    private static func decodedHeaderValue(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return decodeRFC2047(trimmed)
    }

    private static func decodeRFC2047(_ value: String) -> String {
        let pattern = #"=\?([^?]+)\?([BbQq])\?([^?]*)\?="#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let nsValue = value as NSString
        var result = ""
        var lastIndex = 0
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length))
        for match in matches {
            let range = match.range
            if range.location > lastIndex {
                result += nsValue.substring(with: NSRange(location: lastIndex, length: range.location - lastIndex))
            }
            let charset = nsValue.substring(with: match.range(at: 1))
            let encoding = nsValue.substring(with: match.range(at: 2)).uppercased()
            let payload = nsValue.substring(with: match.range(at: 3))
            if encoding == "B", let data = Data(base64Encoded: payload) {
                let text = String(data: data, encoding: charsetEncoding(charset) ?? .utf8) ?? payload
                result += text
            } else if encoding == "Q" {
                let replaced = payload.replacingOccurrences(of: "_", with: " ")
                let data = decodeQuotedPrintable(replaced) ?? Data()
                let text = String(data: data, encoding: charsetEncoding(charset) ?? .utf8) ?? payload
                result += text
            } else {
                result += payload
            }
            lastIndex = range.location + range.length
        }
        if lastIndex < nsValue.length {
            result += nsValue.substring(from: lastIndex)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum LoaderError: LocalizedError {
        case emptyMessage
        case unreadableEncoding
        case invalidFormat
        case emptyBody

        var errorDescription: String? {
            switch self {
            case .emptyMessage:
                return L10n.Error.Eml.emptyMessage
            case .unreadableEncoding:
                return L10n.Error.Eml.unreadableEncoding
            case .invalidFormat:
                return L10n.Error.Eml.invalidFormat
            case .emptyBody:
                return L10n.Error.Eml.emptyBody
            }
        }
    }

    private struct MimePart {
        let headers: [String: String]
        let body: String
    }
}
