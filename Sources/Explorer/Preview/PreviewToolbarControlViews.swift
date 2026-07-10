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
    /// 固定总宽：输入前后保持一致，不因匹配控件出现而撑开。
    static let width: CGFloat = 220
    static let matchStatusWidth: CGFloat = 38
    static let navButtonsWidth: CGFloat = 36
    static let clearButtonWidth: CGFloat = 14
}

struct PreviewTextSearchToolbarControls: View {
    @ObservedObject var session: PreviewSession
    @State private var isSearchFieldFocused = false

    private var trimmedQuery: String {
        session.text.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasQuery: Bool { !trimmedQuery.isEmpty }
    private var matchCount: Int { session.text.searchMatchCount }
    private var hasMatches: Bool { matchCount > 0 }
    private var currentDisplayIndex: Int { session.text.searchCurrentIndex + 1 }

    private var matchStatusLabel: String {
        guard hasQuery else { return "" }
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
                .frame(width: 12)

            PreviewFocuslessTextField(
                text: $session.text.searchQuery,
                placeholder: L10n.Preview.Toolbar.searchPrompt,
                isInline: true,
                isFocused: $isSearchFieldFocused,
                acceptsTabNavigation: true,
                onSubmit: { session.text.findNextSearchMatch() },
                onShiftSubmit: { session.text.findPreviousSearchMatch() },
                onEscape: {
                    session.text.clearSearchQuery()
                    isSearchFieldFocused = false
                }
            )
            .frame(maxWidth: .infinity)
            .background {
                PreviewTextSearchFieldKeyMonitor(
                    isActive: isSearchFieldFocused,
                    onFindNext: { session.text.findNextSearchMatch() },
                    onFindPrevious: { session.text.findPreviousSearchMatch() },
                    onClear: {
                        session.text.clearSearchQuery()
                        isSearchFieldFocused = false
                    }
                )
            }

            Text(matchStatusLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(hasMatches ? Color.secondary : Color.orange)
                .lineLimit(1)
                .frame(width: PreviewToolbarSearchFieldMetrics.matchStatusWidth, alignment: .trailing)
                .opacity(hasQuery ? 1 : 0)
                .instantHoverTooltip(
                    hasQuery
                        ? (hasMatches
                            ? L10n.Preview.Toolbar.searchInPreview
                            : L10n.Preview.Toolbar.searchNoResults)
                        : L10n.Preview.Toolbar.searchInPreview
                )

            HStack(spacing: 0) {
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
            .frame(width: PreviewToolbarSearchFieldMetrics.navButtonsWidth)
            .opacity(hasMatches ? 1 : 0)
            .allowsHitTesting(hasMatches)

            Button {
                session.text.clearSearchQuery()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .frame(width: PreviewToolbarSearchFieldMetrics.clearButtonWidth)
            .opacity(hasQuery ? 1 : 0)
            .allowsHitTesting(hasQuery)
            .instantHoverTooltip(L10n.Preview.Toolbar.clearSearch)
        }
        .padding(.horizontal, PreviewToolbarSearchFieldMetrics.horizontalPadding)
        .frame(
            width: PreviewToolbarSearchFieldMetrics.width - PreviewToolbarSearchFieldMetrics.horizontalPadding * 2,
            height: PreviewToolbarSearchFieldMetrics.height
        )
        .background {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
        }
        .frame(width: PreviewToolbarSearchFieldMetrics.width, height: PreviewToolbarSearchFieldMetrics.height)
        .background {
            TextEditingKeyMonitor(isActive: isSearchFieldFocused)
        }
    }
}

private enum PreviewEpubChapterMenuMetrics {
    static let popoverWidth: CGFloat = 300
    static let popoverMaxHeight: CGFloat = 360
    static let rowHeight: CGFloat = 28
}

struct PreviewEpubChapterMenu: View {
    @ObservedObject var session: PreviewSession
    @State private var isPresented = false

    private var package: EpubPreviewPackage? { session.content.epubPackage }

    private var chapters: [EpubChapterPreview] {
        package?.chapters ?? []
    }

    private var currentChapterIndex: Int {
        guard let package else { return 0 }
        return min(max(session.epub.currentChapterIndex, 0), max(package.chapters.count - 1, 0))
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "list.bullet.indent")
                .font(.body)
                .frame(width: 20, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .focusable(false)
        .instantHoverTooltip(L10n.Preview.Toolbar.epubChapters)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            chapterList
        }
        .disabled(chapters.isEmpty)
    }

    @ViewBuilder
    private var chapterList: some View {
        if chapters.isEmpty {
            Text(L10n.Preview.Epub.noChapters)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(width: PreviewEpubChapterMenuMetrics.popoverWidth)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        Button {
                            session.epub.selectChapter(at: index, chapterCount: chapters.count)
                            isPresented = false
                        } label: {
                            HStack(spacing: 8) {
                                Text(chapter.title)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if index == currentChapterIndex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(index == currentChapterIndex ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                }
            }
            .frame(
                width: PreviewEpubChapterMenuMetrics.popoverWidth,
                height: min(
                    PreviewEpubChapterMenuMetrics.popoverMaxHeight,
                    CGFloat(chapters.count) * PreviewEpubChapterMenuMetrics.rowHeight + 8
                )
            )
        }
    }
}

struct PreviewEpubChapterProgressLabel: View {
    @ObservedObject var session: PreviewSession

    private var package: EpubPreviewPackage? { session.content.epubPackage }

    private var label: String {
        guard let package, !package.chapters.isEmpty else { return "--" }
        let currentIndex = min(max(session.epub.currentChapterIndex, 0), package.chapters.count - 1)
        return L10n.Preview.Epub.chapterProgress(currentIndex + 1, package.chapters.count)
    }

    var body: some View {
        Text(label)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(minWidth: 72, alignment: .center)
            .instantHoverTooltip(L10n.Preview.Toolbar.epubChapters)
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
