import AppKit
import SwiftUI

/// 叠在面包屑段上：仅拦截右键 / Control+点击弹出菜单，左键穿透给下层 Button。
struct PathBarSegmentRightClickOverlay: NSViewRepresentable {
    let path: String
    let actions: PathBarContextActions

    func makeNSView(context: Context) -> PathBarSegmentRightClickView {
        let view = PathBarSegmentRightClickView()
        view.mode = .segment(path: path)
        view.actions = actions
        return view
    }

    func updateNSView(_ nsView: PathBarSegmentRightClickView, context: Context) {
        nsView.mode = .segment(path: path)
        nsView.actions = actions
    }
}

/// 叠在 `…` 上：右键弹出各隐藏段子菜单；左键穿透给下层 Menu。
struct PathBarEllipsisRightClickOverlay: NSViewRepresentable {
    let segments: [PathBarBreadcrumbContextMenuBuilder.HiddenSegment]
    let actions: PathBarContextActions
    let onNavigate: (String) -> Void

    func makeNSView(context: Context) -> PathBarSegmentRightClickView {
        let view = PathBarSegmentRightClickView()
        view.mode = .ellipsis(segments: segments, onNavigate: onNavigate)
        view.actions = actions
        return view
    }

    func updateNSView(_ nsView: PathBarSegmentRightClickView, context: Context) {
        nsView.mode = .ellipsis(segments: segments, onNavigate: onNavigate)
        nsView.actions = actions
    }
}

final class PathBarSegmentRightClickView: NSView {
    enum Mode {
        case segment(path: String)
        case ellipsis(
            segments: [PathBarBreadcrumbContextMenuBuilder.HiddenSegment],
            onNavigate: (String) -> Void
        )
    }

    var mode: Mode = .segment(path: "")
    var actions: PathBarContextActions = .empty

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        switch event.type {
        case .rightMouseDown, .rightMouseUp:
            return self
        case .leftMouseDown, .leftMouseUp:
            if event.modifierFlags.contains(.control) {
                return self
            }
            return nil
        default:
            return nil
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        presentMenu(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            presentMenu(with: event)
            return
        }
        super.mouseDown(with: event)
    }

    private func presentMenu(with event: NSEvent) {
        let menu: NSMenu
        switch mode {
        case .segment(let path):
            menu = PathBarBreadcrumbContextMenuBuilder.makeMenu(
                path: path,
                actions: actions
            )
        case .ellipsis(let segments, let onNavigate):
            menu = PathBarBreadcrumbContextMenuBuilder.makeEllipsisMenu(
                segments: segments,
                actions: actions,
                onNavigate: onNavigate
            )
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
