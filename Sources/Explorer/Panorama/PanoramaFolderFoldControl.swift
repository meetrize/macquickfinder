import SwiftUI

/// 全景目录格左上角统一的展开/折叠控件。
struct PanoramaFolderFoldControl: View {
    enum Action {
        case expand
        case collapse
    }

    let action: Action
    let cellSize: CGFloat
    let onTap: () -> Void

    private var accessibilityLabel: String {
        switch action {
        case .expand: return L10n.Panorama.expandFolder
        case .collapse: return L10n.Panorama.collapseFolder
        }
    }

    private var hitSide: CGFloat {
        max(20, cellSize * 0.20)
    }

    private var iconSize: CGFloat {
        max(13, cellSize * 0.135)
    }

    private var foldIcon: LucideIcon {
        switch action {
        case .expand:
            LucideIcon.chevronRight(size: iconSize)
        case .collapse:
            LucideIcon.chevronDown(size: iconSize)
        }
    }

    var body: some View {
        Button(action: onTap) {
            foldIcon
                .frame(width: hitSide, height: hitSide, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .padding(.top, 3)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
