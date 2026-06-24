import Foundation

/// 文件列表视图模式。
public enum FileListViewMode: String, CaseIterable, Codable, Sendable {
    case list
    case thumbnail
    
    public var displayName: String {
        switch self {
        case .list:
            return L10n.ViewMode.list
        case .thumbnail:
            return L10n.ViewMode.thumbnail
        }
    }
    
    public var systemImageName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .thumbnail:
            return "square.grid.2x2"
        }
    }
}
