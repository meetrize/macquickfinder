import AppKit
import Foundation

/// 多文件列表并存时的焦点与广播注册表。
///
/// - **active**：接收全局动作（重命名、快搜循环等）的当前栏控制器
/// - **selected tab**：当前选中标签（或无标签组时的可见窗）内的列表；元数据刷新应只打这里
/// - **all**：仅用于确需跨标签同步的少数场景
///
/// 单栏时行为与旧 `FileListTableController.shared` 一致（后创建 / 获焦者成为 active）。
/// 约定：仅在主线程读写（与 AppKit 列表生命周期一致）。
public enum FileListFocusRegistry {
    private static var tableBoxes: [WeakTableBox] = []
    private static var thumbnailBoxes: [WeakThumbnailBox] = []
    private static weak var activeTableRef: FileListTableController?
    private static weak var activeThumbnailRef: FileListThumbnailController?

    // MARK: - Active (keyboard / rename / quick search)

    public static var activeTable: FileListTableController? {
        prune()
        return activeTableRef ?? tableBoxes.reversed().compactMap(\.value).first
    }

    public static var activeThumbnail: FileListThumbnailController? {
        prune()
        return activeThumbnailRef ?? thumbnailBoxes.reversed().compactMap(\.value).first
    }

    // MARK: - All live controllers

    public static var allTables: [FileListTableController] {
        prune()
        return tableBoxes.compactMap(\.value)
    }

    public static var allThumbnails: [FileListThumbnailController] {
        prune()
        return thumbnailBoxes.compactMap(\.value)
    }

    /// 判断窗口是否为当前应刷新 UI 的标签页（多标签时仅 `selectedWindow`）。
    public static func isSelectedTabWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        if let group = window.tabGroup {
            return group.selectedWindow === window
        }
        return window.isVisible || window.isKeyWindow
    }

    // MARK: - Registration

    public static func register(_ controller: FileListTableController) {
        prune()
        if !tableBoxes.contains(where: { $0.value === controller }) {
            tableBoxes.append(WeakTableBox(controller))
        }
        activeTableRef = controller
    }

    public static func register(_ controller: FileListThumbnailController) {
        prune()
        if !thumbnailBoxes.contains(where: { $0.value === controller }) {
            thumbnailBoxes.append(WeakThumbnailBox(controller))
        }
        activeThumbnailRef = controller
    }

    public static func unregister(_ controller: FileListTableController) {
        tableBoxes.removeAll { $0.value == nil || $0.value === controller }
        if activeTableRef === controller {
            activeTableRef = tableBoxes.compactMap(\.value).last
        }
    }

    public static func unregister(_ controller: FileListThumbnailController) {
        thumbnailBoxes.removeAll { $0.value == nil || $0.value === controller }
        if activeThumbnailRef === controller {
            activeThumbnailRef = thumbnailBoxes.compactMap(\.value).last
        }
    }

    public static func claimActive(_ controller: FileListTableController) {
        if !tableBoxes.contains(where: { $0.value === controller }) {
            tableBoxes.append(WeakTableBox(controller))
        }
        activeTableRef = controller
    }

    public static func claimActive(_ controller: FileListThumbnailController) {
        if !thumbnailBoxes.contains(where: { $0.value === controller }) {
            thumbnailBoxes.append(WeakThumbnailBox(controller))
        }
        activeThumbnailRef = controller
    }

    // MARK: - Broadcast helpers

    public static func forEachTable(_ body: (FileListTableController) -> Void) {
        for table in allTables {
            body(table)
        }
    }

    public static func forEachThumbnail(_ body: (FileListThumbnailController) -> Void) {
        for thumbnail in allThumbnails {
            body(thumbnail)
        }
    }

    /// 仅刷新当前选中标签内的列表（含双栏同窗的两个表）；跳过后台标签以避免 O(标签数) 主线程开销。
    public static func forEachSelectedTabTable(_ body: (FileListTableController) -> Void) {
        for table in allTables where table.isInSelectedTabWindow {
            body(table)
        }
    }

    public static func forEachSelectedTabThumbnail(_ body: (FileListThumbnailController) -> Void) {
        for thumbnail in allThumbnails where thumbnail.isInSelectedTabWindow {
            body(thumbnail)
        }
    }

    // MARK: - Private

    private static func prune() {
        tableBoxes.removeAll { $0.value == nil }
        thumbnailBoxes.removeAll { $0.value == nil }
        if activeTableRef == nil {
            activeTableRef = tableBoxes.compactMap(\.value).last
        }
        if activeThumbnailRef == nil {
            activeThumbnailRef = thumbnailBoxes.compactMap(\.value).last
        }
    }
}

private final class WeakTableBox {
    weak var value: FileListTableController?
    init(_ value: FileListTableController) { self.value = value }
}

private final class WeakThumbnailBox {
    weak var value: FileListThumbnailController?
    init(_ value: FileListThumbnailController) { self.value = value }
}
