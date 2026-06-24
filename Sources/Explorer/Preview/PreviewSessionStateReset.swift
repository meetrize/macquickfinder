import AppKit
import Foundation

/// 按预览类型分组的重置逻辑，供 `resetControls` 与 `prepareForLoad` 复用。
@MainActor
enum PreviewSessionStateReset {
    static func resetImageToolbar(on session: PreviewSession) {
        session.image.resetToolbar()
    }

    static func resetPDFToolbar(on session: PreviewSession) {
        session.pdf.resetToolbar()
    }

    static func resetTextToolbar(on session: PreviewSession) {
        session.text.resetToolbar()
    }

    static func resetMediaToolbar(on session: PreviewSession) {
        session.media.resetToolbar()
    }

    static func resetOfficeToolbar(on session: PreviewSession) {
        session.office.resetToolbar()
    }

    static func resetArchiveToolbar(on session: PreviewSession) {
        session.archive.resetToolbar()
    }

    /// 切换预览文件或文件夹内联子项时重置全部工具栏控件。
    static func resetAllToolbarControls(on session: PreviewSession) {
        resetImageToolbar(on: session)
        resetPDFToolbar(on: session)
        resetTextToolbar(on: session)
        resetMediaToolbar(on: session)
        resetOfficeToolbar(on: session)
        resetArchiveToolbar(on: session)
    }

    /// 开始加载新内容前重置工具栏（保留 markdown/html 显示模式与 archive 展开状态）。
    static func prepareToolbarForLoad(on session: PreviewSession) {
        session.image.prepareForLoad()
        resetTextToolbar(on: session)
        resetMediaToolbar(on: session)
        resetOfficeToolbar(on: session)
        session.archive.prepareForLoad()
        resetPDFToolbar(on: session)
    }
}
