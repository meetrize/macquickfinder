import Foundation
import Combine

/// 用户可配置的预览方式。
enum CustomPreviewMode: String, Codable, CaseIterable, Identifiable {
    case text
    case markdown
    case html
    case quickLook
    case image
    case pdf
    case media

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "文本预览"
        case .markdown: return "Markdown 预览"
        case .html: return "HTML 预览"
        case .quickLook: return "QuickLook 预览"
        case .image: return "图片预览"
        case .pdf: return "PDF 预览"
        case .media: return "媒体预览"
        }
    }

    var detail: String {
        switch self {
        case .text:
            return "以纯文本显示，并根据扩展名做语法高亮。"
        case .markdown:
            return "渲染 Markdown；可在顶栏切换源码视图。"
        case .html:
            return "在 WebKit 中渲染 HTML；可切换源码视图。"
        case .quickLook:
            return "使用 macOS QuickLook，适合系统已支持预览的格式。"
        case .image:
            return "尝试按图片解码并显示。"
        case .pdf:
            return "使用 PDFKit 显示 PDF 文档。"
        case .media:
            return "使用 AVPlayer 播放音视频。"
        }
    }
}

struct CustomPreviewRule: Codable, Identifiable, Equatable {
    /// 存储与索引用的无扩展名占位 key（`pathExtension` 为空时映射为此值）。
    static let extensionlessKey = "__noext__"

    var id: UUID
    var extensions: [String]
    var mode: CustomPreviewMode
    /// false = 仅在内置不识别时生效；true = 覆盖内置预览。
    var overridesBuiltIn: Bool
    var enabled: Bool

    init(
        id: UUID = UUID(),
        extensions: [String],
        mode: CustomPreviewMode,
        overridesBuiltIn: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.extensions = extensions
        self.mode = mode
        self.overridesBuiltIn = overridesBuiltIn
        self.enabled = enabled
    }

    var normalizedExtensions: [String] {
        extensions.map { Self.normalizeExtension($0) }.filter { !$0.isEmpty }
    }

    static func storageKey(forPathExtension ext: String) -> String {
        ext.isEmpty ? extensionlessKey : ext.lowercased()
    }

    static func displayLabel(forExtension ext: String) -> String {
        ext == extensionlessKey ? "（无扩展名）" : ".\(ext)"
    }

    static func isExtensionlessToken(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty { return true }
        if text == "（无扩展名）" || text == "(无扩展名)" { return true }
        return text == extensionlessKey
    }

    static func normalizeExtension(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while text.hasPrefix(".") { text.removeFirst() }
        if isExtensionlessToken(text) { return extensionlessKey }
        return text
    }

    static func parseExtensions(from input: String) -> [String] {
        input
            .split { $0 == "," || $0 == ";" || $0.isWhitespace }
            .map { normalizeExtension(String($0)) }
            .filter { !$0.isEmpty }
    }
}

/// 内置预览扩展名集合，与 `FileContentView.loadContent` 保持一致。
enum BuiltinPreviewExtensions {
    static let image: Set<String> = ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic", "webp"]
    static let media: Set<String> = ["mp4", "mov", "mp3", "wav"]
    static let office: Set<String> = ["docx", "xlsx", "ppt", "pptx"]
    /// 幻灯片类 Office 文件（Quick Look 多页预览）。
    static let presentation: Set<String> = ["ppt", "pptx"]
    static let pdf: Set<String> = ["pdf"]
    static let text: Set<String> = [
        "txt", "md", "swift", "java", "py", "js", "ts", "go", "rs", "kt", "php", "rb",
        "html", "css", "json", "xml", "c", "cpp", "h", "sh", "yaml", "yml", "vue",
        "config", "ini", "gitignore", "properties", "log", "sql", "csv"
    ]
    static let html: Set<String> = ["html", "htm"]
    static let markdown: Set<String> = ["md"]

    static func matchesBuiltIn(_ ext: String) -> Bool {
        let lower = ext.lowercased()
        if image.contains(lower) { return true }
        if media.contains(lower) { return true }
        if office.contains(lower) { return true }
        if pdf.contains(lower) { return true }
        if text.contains(lower) { return true }
        return false
    }

    static func matchesArchive(fileName: String) -> Bool {
        let lower = fileName.lowercased()
        return lower.hasSuffix(".zip")
            || lower.hasSuffix(".tar")
            || lower.hasSuffix(".tar.gz")
            || lower.hasSuffix(".tgz")
    }

    static var catalogByMode: [(mode: String, extensions: [String])] {
        [
            ("图片", image.sorted()),
            ("PDF", pdf.sorted()),
            ("媒体", media.sorted()),
            ("Office (QuickLook)", office.sorted()),
            ("文本 / 代码", text.sorted()),
            ("压缩包", ["zip", "tar", "tar.gz", "tgz"])
        ]
    }
}

@MainActor
enum PreviewTypeClassifier {
    static func customMode(forExtension ext: String) -> CustomPreviewMode? {
        CustomPreviewRuleStore.shared.activeMode(for: ext)
    }

    static func isTextFile(_ ext: String) -> Bool {
        if BuiltinPreviewExtensions.text.contains(ext.lowercased()) { return true }
        return customMode(forExtension: ext) == .text
    }

    static func isMarkdownFile(_ ext: String) -> Bool {
        if BuiltinPreviewExtensions.markdown.contains(ext.lowercased()) { return true }
        return customMode(forExtension: ext) == .markdown
    }

    static func isHtmlFile(_ ext: String) -> Bool {
        if BuiltinPreviewExtensions.html.contains(ext.lowercased()) { return true }
        return customMode(forExtension: ext) == .html
    }

    static func isImageFile(_ ext: String) -> Bool {
        if BuiltinPreviewExtensions.image.contains(ext.lowercased()) { return true }
        return customMode(forExtension: ext) == .image
    }

    static func isPDFFile(_ ext: String) -> Bool {
        if BuiltinPreviewExtensions.pdf.contains(ext.lowercased()) { return true }
        return customMode(forExtension: ext) == .pdf
    }

    static func isMediaFile(_ ext: String) -> Bool {
        if BuiltinPreviewExtensions.media.contains(ext.lowercased()) { return true }
        return customMode(forExtension: ext) == .media
    }

    static func isOfficeFile(_ ext: String) -> Bool {
        if BuiltinPreviewExtensions.office.contains(ext.lowercased()) { return true }
        return customMode(forExtension: ext) == .quickLook
    }
}

@MainActor
final class CustomPreviewRuleStore: ObservableObject {
    static let shared = CustomPreviewRuleStore()

    @Published private(set) var rules: [CustomPreviewRule] = [] {
        didSet { rebuildIndex() }
    }

    @Published private(set) var revision: UInt = 0

    private(set) var extensionIndex: [String: CustomPreviewRule] = [:]

    private init() {
        load()
        rebuildIndex()
    }

    func activeMode(for ext: String) -> CustomPreviewMode? {
        let key = CustomPreviewRule.storageKey(forPathExtension: ext)
        guard let rule = extensionIndex[key], rule.enabled else { return nil }
        if rule.overridesBuiltIn { return rule.mode }
        if !BuiltinPreviewExtensions.matchesBuiltIn(ext)
            && !BuiltinPreviewExtensions.matchesArchive(fileName: "file.\(ext)") {
            return rule.mode
        }
        return nil
    }

    func overridingRule(for ext: String) -> CustomPreviewRule? {
        let key = CustomPreviewRule.storageKey(forPathExtension: ext)
        guard let rule = extensionIndex[key], rule.enabled, rule.overridesBuiltIn else {
            return nil
        }
        return rule
    }

    func rule(forExtension ext: String) -> CustomPreviewRule? {
        extensionIndex[CustomPreviewRule.storageKey(forPathExtension: ext)]
    }

    func upsertRule(forExtension ext: String, mode: CustomPreviewMode, overridesBuiltIn: Bool = false) {
        let normalized = CustomPreviewRule.normalizeExtension(ext)
        guard !normalized.isEmpty else { return }

        if var existing = extensionIndex[normalized] {
            existing.mode = mode
            existing.overridesBuiltIn = overridesBuiltIn
            existing.enabled = true
            if !existing.extensions.contains(normalized) {
                existing.extensions.append(normalized)
            }
            updateRule(existing)
            return
        }

        let rule = CustomPreviewRule(
            extensions: [normalized],
            mode: mode,
            overridesBuiltIn: overridesBuiltIn
        )
        rules.append(rule)
        persist()
        bumpRevision()
    }

    func addRule(_ rule: CustomPreviewRule) {
        rules.append(rule)
        persist()
        bumpRevision()
    }

    func updateRule(_ rule: CustomPreviewRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        persist()
        bumpRevision()
    }

    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
        bumpRevision()
    }

    func exportJSON() throws -> Data {
        try JSONEncoder().encode(rules)
    }

    func importJSON(_ data: Data, merge: Bool) throws {
        let decoded = try JSONDecoder().decode([CustomPreviewRule].self, from: data)
        if merge {
            for rule in decoded {
                if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                    rules[index] = rule
                } else {
                    rules.append(rule)
                }
            }
        } else {
            rules = decoded
        }
        persist()
        bumpRevision()
    }

    private func rebuildIndex() {
        var index: [String: CustomPreviewRule] = [:]
        for rule in rules where rule.enabled {
            for ext in rule.normalizedExtensions {
                index[ext] = rule
            }
        }
        extensionIndex = index
    }

    private func bumpRevision() {
        revision &+= 1
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: ExplorerAppSettings.customPreviewRulesKey) else {
            rules = []
            return
        }
        rules = (try? JSONDecoder().decode([CustomPreviewRule].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: ExplorerAppSettings.customPreviewRulesKey)
    }
}
