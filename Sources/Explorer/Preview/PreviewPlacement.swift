import Foundation

/// 主浏览窗口内预览的安置状态：侧栏 inline 或已弹出到独立窗口。
enum PreviewPlacement: Equatable, Sendable {
    case inline
    case detached(sessionID: PreviewSessionID, fileID: FileItem.ID)

    var isDetached: Bool {
        if case .detached = self { return true }
        return false
    }

    /// 若处于 detached 且选中文件与弹出文件相同，侧栏应显示占位条而非 inline 预览。
    func showsPlaceholder(forSelectedFileID selectedFileID: FileItem.ID?) -> Bool {
        guard let selectedFileID else { return false }
        if case .detached(_, let fileID) = self {
            return fileID == selectedFileID
        }
        return false
    }

    func detachedSessionID(forFileID fileID: FileItem.ID) -> PreviewSessionID? {
        if case .detached(let sessionID, let detachedFileID) = self, detachedFileID == fileID {
            return sessionID
        }
        return nil
    }
}
