import Foundation

/// 应用内双击可预览文件时的行为（⌥ 双击始终独立预览窗）。
enum PreviewDoubleClickAction: String, CaseIterable, Identifiable, Codable {
    case defaultApp
    case standalonePreview
    case sidebarPreview

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultApp:
            return L10n.Settings.Preview.DoubleClick.defaultApp
        case .standalonePreview:
            return L10n.Settings.Preview.DoubleClick.standalonePreview
        case .sidebarPreview:
            return L10n.Settings.Preview.DoubleClick.sidebarPreview
        }
    }

    static let defaultValue: PreviewDoubleClickAction = .defaultApp
}
