import Foundation

/// 应用内普通双击压缩包时的行为（⌥ 双击始终独立预览）。
enum PreviewArchiveDoubleClickAction: String, CaseIterable, Identifiable, Codable {
    case extract
    case preview

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .extract:
            return L10n.Settings.Preview.ArchiveDoubleClick.extract
        case .preview:
            return L10n.Settings.Preview.ArchiveDoubleClick.preview
        }
    }

    static let defaultValue: PreviewArchiveDoubleClickAction = .extract
}
