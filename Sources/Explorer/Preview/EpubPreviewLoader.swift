import Foundation

struct EpubMetadata: Equatable {
    let title: String?
    let author: String?
}

struct EpubChapterPreview: Identifiable, Equatable {
    let id: String
    let title: String
    let fileURL: URL
}

struct EpubPreviewPackage: Equatable {
    let metadata: EpubMetadata
    let chapters: [EpubChapterPreview]
    let extractedRoot: URL
}

/// 解包 EPUB（ZIP）并解析 OPF 书脊，供 WKWebView 按章节预览。
enum EpubPreviewLoader {
    static let maxChapters = 500

    private static let chapterMediaTypes: Set<String> = [
        "application/xhtml+xml",
        "application/x-dtbook+xml",
        "text/html",
        "text/x-html",
    ]

    static func load(from url: URL) throws -> EpubPreviewPackage {
        let extractedRoot = try unzipToTemporaryDirectory(url: url)
        do {
            let opfURL = try resolveOPFURL(in: extractedRoot)
            let opfDirectory = opfURL.deletingLastPathComponent()
            let parser = OPFParser()
            let xml = XMLParser(data: try Data(contentsOf: opfURL))
            xml.delegate = parser
            guard xml.parse() else {
                throw LoaderError.invalidOPF
            }

            var chapters: [EpubChapterPreview] = []
            chapters.reserveCapacity(min(parser.spineIDRefs.count, maxChapters))
            for (index, idRef) in parser.spineIDRefs.enumerated() {
                if chapters.count >= maxChapters { break }
                guard let item = parser.manifest[idRef] else { continue }
                guard chapterMediaTypes.contains(item.mediaType.lowercased()) else { continue }
                guard let chapterURL = resolveChapterURL(href: item.href, relativeTo: opfDirectory) else { continue }
                guard FileManager.default.fileExists(atPath: chapterURL.path) else { continue }

                let title = chapterTitle(for: item.href, index: index)
                chapters.append(
                    EpubChapterPreview(
                        id: idRef,
                        title: title,
                        fileURL: chapterURL
                    )
                )
            }

            guard !chapters.isEmpty else {
                throw LoaderError.emptySpine
            }

            return EpubPreviewPackage(
                metadata: EpubMetadata(title: parser.title, author: parser.author),
                chapters: chapters,
                extractedRoot: extractedRoot
            )
        } catch {
            cleanup(extractedRoot: extractedRoot)
            throw error
        }
    }

    static func cleanup(extractedRoot: URL?) {
        guard let extractedRoot else { return }
        try? FileManager.default.removeItem(at: extractedRoot)
    }

    private static func unzipToTemporaryDirectory(url: URL) throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-epub-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", url.path, "-d", dest.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: dest)
            throw LoaderError.unzipFailed(code: process.terminationStatus)
        }
        return dest
    }

    private static func resolveOPFURL(in extractedRoot: URL) throws -> URL {
        let containerURL = extractedRoot
            .appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw LoaderError.containerNotFound
        }

        let parser = ContainerXMLParser()
        let xml = XMLParser(data: try Data(contentsOf: containerURL))
        xml.delegate = parser
        guard xml.parse(), let opfPath = parser.rootFilePath, !opfPath.isEmpty else {
            throw LoaderError.containerNotFound
        }

        let opfURL = extractedRoot.appendingPathComponent(opfPath)
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw LoaderError.opfNotFound
        }
        return opfURL
    }

    private static func resolveChapterURL(href: String, relativeTo opfDirectory: URL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed, relativeTo: opfDirectory) {
            return url.standardizedFileURL
        }
        return opfDirectory.appendingPathComponent(trimmed).standardizedFileURL
    }

    private static func chapterTitle(for href: String, index: Int) -> String {
        let baseName = URL(fileURLWithPath: href).deletingPathExtension().lastPathComponent
        if baseName.isEmpty || baseName == "/" {
            return "Chapter \(index + 1)"
        }
        return baseName
    }

    enum LoaderError: LocalizedError {
        case unzipFailed(code: Int32)
        case containerNotFound
        case opfNotFound
        case invalidOPF
        case emptySpine

        var errorDescription: String? {
            switch self {
            case .unzipFailed:
                return L10n.Error.Epub.unzipFailed
            case .containerNotFound:
                return L10n.Error.Epub.containerNotFound
            case .opfNotFound:
                return L10n.Error.Epub.opfNotFound
            case .invalidOPF:
                return L10n.Error.Epub.invalidOPF
            case .emptySpine:
                return L10n.Error.Epub.emptySpine
            }
        }
    }
}

// MARK: - XML parsers

private final class ContainerXMLParser: NSObject, XMLParserDelegate {
    var rootFilePath: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.hasSuffix("rootfile") else { return }
        guard let mediaType = attributeDict["media-type"]?.lowercased() else { return }
        guard mediaType.contains("opf") || mediaType.contains("oebps-package") else { return }
        rootFilePath = attributeDict["full-path"]
    }
}

private final class OPFParser: NSObject, XMLParserDelegate {
    var title: String?
    var author: String?
    var manifest: [String: (href: String, mediaType: String)] = [:]
    var spineIDRefs: [String] = []

    private var inMetadata = false
    private var metadataField: MetadataField?
    private var metadataText = ""

    private enum MetadataField {
        case title
        case author
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName.hasSuffix("metadata") {
            inMetadata = true
        }

        if inMetadata {
            if elementName.hasSuffix("title") {
                metadataField = .title
                metadataText = ""
            } else if elementName.hasSuffix("creator") {
                metadataField = .author
                metadataText = ""
            }
        }

        if elementName.hasSuffix("item"),
           let id = attributeDict["id"],
           let href = attributeDict["href"] {
            let mediaType = attributeDict["media-type"] ?? ""
            manifest[id] = (href, mediaType)
        }

        if elementName.hasSuffix("itemref"), let idref = attributeDict["idref"] {
            spineIDRefs.append(idref)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard metadataField != nil else { return }
        metadataText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName.hasSuffix("metadata") {
            inMetadata = false
        }

        guard let field = metadataField else { return }
        let value = metadataText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            metadataField = nil
            metadataText = ""
            return
        }

        switch field {
        case .title where title == nil:
            title = value
        case .author where author == nil:
            author = value
        default:
            break
        }
        metadataField = nil
        metadataText = ""
    }
}
