import Foundation

/// Finder / Dock 等外部入口打开可预览文件时的行为。
enum PreviewExternalOpenAction: String, CaseIterable, Identifiable, Codable {
    case standaloneOnly
    case browserAndSelect

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standaloneOnly:
            return L10n.Settings.Preview.ExternalOpen.standaloneOnly
        case .browserAndSelect:
            return L10n.Settings.Preview.ExternalOpen.browserAndSelect
        }
    }

    static let defaultValue: PreviewExternalOpenAction = .standaloneOnly
}
