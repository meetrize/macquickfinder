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

private enum PreviewToolbarSearchFieldMetrics {
    static let height: CGFloat = 24
    static let horizontalPadding: CGFloat = 8
}

struct PreviewTextSearchToolbarControls: View {
    @ObservedObject var session: PreviewSession

    private var trimmedQuery: String {
        session.text.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasQuery: Bool { !trimmedQuery.isEmpty }
    private var matchCount: Int { session.text.searchMatchCount }
    private var hasMatches: Bool { matchCount > 0 }
    private var currentDisplayIndex: Int { session.text.searchCurrentIndex + 1 }

    private var matchStatusLabel: String? {
        guard hasQuery else { return nil }
        if hasMatches {
            return matchCount > 1
                ? "\(currentDisplayIndex)/\(matchCount)"
                : "\(matchCount)"
        }
        return L10n.Preview.Toolbar.searchNoResults
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            PreviewFocuslessTextField(
                text: $session.text.searchQuery,
                placeholder: L10n.Preview.Toolbar.searchPrompt,
                isInline: true,
                onSubmit: { session.text.findNextSearchMatch() },
                onShiftSubmit: { session.text.findPreviousSearchMatch() }
            )
            .frame(minWidth: 96, maxWidth: 160)

            if let matchStatusLabel {
                Text(matchStatusLabel)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(hasMatches ? Color.secondary : Color.orange)
                    .lineLimit(1)
                    .fixedSize()
                    .instantHoverTooltip(
                        hasMatches
                            ? L10n.Preview.Toolbar.searchInPreview
                            : L10n.Preview.Toolbar.searchNoResults
                    )
            }

            if hasMatches {
                PreviewFocuslessIconButton(
                    systemImageName: "chevron.up",
                    accessibilityLabel: L10n.Preview.Toolbar.previousMatch,
                    action: { session.text.findPreviousSearchMatch() }
                )
                .instantHoverTooltip(L10n.Preview.Toolbar.previousMatch)

                PreviewFocuslessIconButton(
                    systemImageName: "chevron.down",
                    accessibilityLabel: L10n.Preview.Toolbar.nextMatch,
                    action: { session.text.findNextSearchMatch() }
                )
                .instantHoverTooltip(L10n.Preview.Toolbar.nextMatch)
            }

            if hasQuery {
                Button {
                    session.text.clearSearchQuery()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .instantHoverTooltip(L10n.Preview.Toolbar.clearSearch)
            }
        }
        .padding(.horizontal, PreviewToolbarSearchFieldMetrics.horizontalPadding)
        .frame(height: PreviewToolbarSearchFieldMetrics.height)
        .background {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
        }
        .frame(minWidth: 168, maxWidth: 280, alignment: .trailing)
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
