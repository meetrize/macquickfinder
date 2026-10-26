import AppKit
import SwiftUI

/// 悬停预览只读内容（无工具栏、无编辑）。
struct HoverPreviewContentView: View {
    let fileName: String
    let payload: HoverPreviewPayload
    let panelSize: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(fileName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: panelSize.width, height: panelSize.height)
    }

    @ViewBuilder
    private var content: some View {
        switch payload {
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
        case .text(let text):
            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.disabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        case .meta(let meta):
            VStack(alignment: .leading, spacing: 8) {
                Text(meta.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                if let detail = meta.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(20)
        case .placeholder:
            ProgressView()
                .controlSize(.regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
