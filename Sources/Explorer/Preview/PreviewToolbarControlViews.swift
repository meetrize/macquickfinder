import SwiftUI

struct PreviewImageZoomToolbarControls: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 2) {
            PreviewFocuslessIconButton(
                systemImageName: "minus.magnifyingglass",
                accessibilityLabel: L10n.Preview.Toolbar.zoomOut,
                action: { session.image.zoomScale = max(session.image.zoomScale - 0.25, 0.1) }
            )
            .disabled(session.image.zoomScale <= 0.1)
            .instantHoverTooltip(L10n.Preview.Toolbar.zoomOut)

            PreviewFocuslessIconButton(
                systemImageName: "plus.magnifyingglass",
                accessibilityLabel: L10n.Preview.Toolbar.zoomIn,
                action: { session.image.zoomScale = min(session.image.zoomScale + 0.25, 5.0) }
            )
            .instantHoverTooltip(L10n.Preview.Toolbar.zoomIn)

            PreviewFocuslessIconButton(
                systemImageName: "arrow.up.left.and.arrow.down.right",
                accessibilityLabel: L10n.Preview.Toolbar.fitWindow,
                action: { session.image.zoomAction = .fit }
            )
            .instantHoverTooltip(L10n.Preview.Toolbar.fitWindow)

            PreviewFocuslessIconButton(
                systemImageName: "1.magnifyingglass",
                accessibilityLabel: L10n.Preview.Toolbar.actualSize,
                action: { session.image.zoomAction = .actualSize }
            )
            .instantHoverTooltip(L10n.Preview.Toolbar.actualSize)

            Text(session.image.effectiveZoomPercent > 0 ? "\(session.image.effectiveZoomPercent)%" : "--")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 36, alignment: .center)
                .instantHoverTooltip(L10n.Preview.Toolbar.zoomScale)
        }
    }
}

struct PreviewImageEyedropperToolbarButton: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        PreviewFocuslessIconButton(
            systemImageName: "eyedropper",
            accessibilityLabel: L10n.Preview.Toolbar.colorPicker,
            isActive: session.image.eyedropperActive,
            action: { session.image.eyedropperActive.toggle() }
        )
        .instantHoverTooltip(L10n.Preview.Toolbar.colorPicker)
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
        .instantHoverTooltip(L10n.Preview.Toolbar.copiedToClipboard)
    }
}

struct PreviewTextSearchToolbarControls: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            PreviewFocuslessTextField(
                text: $session.text.searchQuery,
                placeholder: L10n.Preview.Toolbar.searchPrompt,
                width: 120,
                onSubmit: { session.text.findNextSearchMatch() }
            )
            .frame(minWidth: 88, maxWidth: 120)

            if session.text.searchMatchCount > 1 {
                PreviewFocuslessIconButton(
                    systemImageName: "chevron.down",
                    accessibilityLabel: L10n.Preview.Toolbar.nextMatch,
                    action: { session.text.findNextSearchMatch() }
                )
                .instantHoverTooltip(L10n.Preview.Toolbar.nextMatch)
            }
        }
        .frame(minWidth: 120, alignment: .trailing)
        .instantHoverTooltip(L10n.Preview.Toolbar.searchInPreview)
    }
}

struct PreviewPDFPageInputField: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 4) {
            PreviewFocuslessTextField(
                text: $session.pdf.pageInput,
                placeholder: "",
                width: 44,
                onSubmit: {
                    let trimmed = session.pdf.pageInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let page = Int(trimmed), session.pdf.pageCount > 0 else {
                        session.pdf.pageInput = session.pdf.currentPage > 0 ? "\(session.pdf.currentPage)" : ""
                        return
                    }
                    let clamped = min(max(page, 1), session.pdf.pageCount)
                    session.pdf.navigateAction = .goToPage(clamped)
                }
            )

            Text("/\(session.pdf.pageCount > 0 ? "\(session.pdf.pageCount)" : "--")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 74, alignment: .center)
        .instantHoverTooltip(L10n.Preview.Toolbar.jumpToPage)
    }
}
