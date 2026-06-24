import SwiftUI

struct PreviewPlaceholderView: View {
    let fileName: String
    let onFocus: () -> Void
    let onDockBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "macwindow")
                    .foregroundStyle(.secondary)

                Text(L10n.Preview.previewingInDetachedWindow(fileName))
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                Button(L10n.Preview.focusWindow, action: onFocus)
                    .buttonStyle(.borderless)

                Button(L10n.Preview.dockBack, action: onDockBack)
                    .buttonStyle(.borderless)
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .padding(.horizontal, 10)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
