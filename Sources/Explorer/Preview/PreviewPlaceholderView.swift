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

                Text("\(fileName) 已在独立窗口中预览")
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                Button("聚焦窗口", action: onFocus)
                    .buttonStyle(.borderless)

                Button("收回侧栏", action: onDockBack)
                    .buttonStyle(.borderless)
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .padding(.horizontal, 10)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
