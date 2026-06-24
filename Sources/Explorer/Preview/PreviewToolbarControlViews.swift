import SwiftUI

struct PreviewImageZoomToolbarControls: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 2) {
            Button {
                session.image.zoomScale = max(session.image.zoomScale - 0.25, 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .instantHoverTooltip("缩小")
            .disabled(session.image.zoomScale <= 0.1)

            Button {
                session.image.zoomScale = min(session.image.zoomScale + 0.25, 5.0)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .instantHoverTooltip("放大")

            Button {
                session.image.zoomAction = .fit
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .instantHoverTooltip("适配窗口")

            Button {
                session.image.zoomAction = .actualSize
            } label: {
                Image(systemName: "1.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .instantHoverTooltip("原始大小")

            Text(session.image.effectiveZoomPercent > 0 ? "\(session.image.effectiveZoomPercent)%" : "--")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 36, alignment: .center)
                .instantHoverTooltip("缩放比例")
        }
    }
}

struct PreviewImageEyedropperToolbarButton: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        Button {
            session.image.eyedropperActive.toggle()
        } label: {
            Image(systemName: "eyedropper")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    session.image.eyedropperActive ? Color.accentColor : Color.primary,
                    Color.primary
                )
        }
        .buttonStyle(.borderless)
        .instantHoverTooltip("取色棒（点击图像复制 Web 颜色）")
    }
}

struct PreviewImageColorSwatch: View {
    let hex: String
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(session.colorFromWebHex(hex))
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
            Text(hex)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .instantHoverTooltip("已复制到剪贴板")
    }
}

struct PreviewTextSearchToolbarControls: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("搜索", text: $session.text.searchQuery)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 96)
                .onSubmit {
                    session.text.findNextSearchMatch()
                }

            if session.text.searchMatchCount > 1 {
                Button {
                    session.text.findNextSearchMatch()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .instantHoverTooltip("下一个")
            }
        }
        .frame(minWidth: 120, alignment: .trailing)
        .instantHoverTooltip("在预览中搜索")
    }
}

struct PreviewPDFPageInputField: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $session.pdf.pageInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 44)
                .onSubmit {
                    let trimmed = session.pdf.pageInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let page = Int(trimmed), session.pdf.pageCount > 0 else {
                        session.pdf.pageInput = session.pdf.currentPage > 0 ? "\(session.pdf.currentPage)" : ""
                        return
                    }
                    let clamped = min(max(page, 1), session.pdf.pageCount)
                    session.pdf.navigateAction = .goToPage(clamped)
                }

            Text("/\(session.pdf.pageCount > 0 ? "\(session.pdf.pageCount)" : "--")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 74, alignment: .center)
        .instantHoverTooltip("跳转到页码")
    }
}
