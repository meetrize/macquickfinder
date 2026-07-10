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

    private var iconName: String {
        switch action {
        case .expand: return "chevron.right"
        case .collapse: return "chevron.down"
        }
    }

    private var accessibilityLabel: String {
        switch action {
        case .expand: return L10n.Panorama.expandFolder
        case .collapse: return L10n.Panorama.collapseFolder
        }
    }

    private var controlSide: CGFloat {
        max(22, cellSize * 0.22)
    }

    var body: some View {
        Button(action: onTap) {
            Image(systemName: iconName)
                .font(.system(size: controlSide * 0.46, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: controlSide, height: controlSide)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.92))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.14), radius: 1.5, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
