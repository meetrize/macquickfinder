import SwiftUI

struct HelpCheatSheetView: View {
    var body: some View {
        GeometryReader { geometry in
            let layout = HelpCheatSheetLayoutEngine.layout(for: geometry.size.width)

            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ScrollView(scrollAxes(contentWidth: layout.contentWidth, containerWidth: geometry.size.width)) {
                    HStack(alignment: .top, spacing: layout.columnGap) {
                        ForEach(layout.columns) { column in
                            columnPanel(column)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HelpCheatSheetLayoutEngine.viewHorizontalPadding)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    private func scrollAxes(contentWidth: CGFloat, containerWidth: CGFloat) -> Axis.Set {
        let usableWidth = containerWidth - HelpCheatSheetLayoutEngine.viewHorizontalPadding * 2
        if contentWidth > usableWidth {
            return [.vertical, .horizontal]
        }
        return .vertical
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Help.windowTitle)
                    .font(.title3.weight(.semibold))
                Text(L10n.Help.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HelpCheatSheetLayoutEngine.viewHorizontalPadding)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func columnPanel(_ column: HelpCheatSheetColumnLayout) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            columnHeaders(column)
            ForEach(column.sections) { section in
                sectionBlock(section, column: column)
            }
        }
        .frame(width: column.width, alignment: .topLeading)
    }

    private func columnHeaders(_ column: HelpCheatSheetColumnLayout) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HelpCheatSheetLayoutEngine.columnSpacing) {
            Text(L10n.Help.columnFeature)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: column.nameWidth, alignment: .leading)
            Text(L10n.Help.columnDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: column.descriptionWidth, alignment: .leading)
            Text(L10n.Help.columnShortcut)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: column.shortcutWidth, alignment: .trailing)
        }
        .padding(.horizontal, HelpCheatSheetLayoutEngine.horizontalPadding)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35))
        )
    }

    @ViewBuilder
    private func sectionBlock(_ section: HelpCheatSheetSection, column: HelpCheatSheetColumnLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Help.sectionTitle(section.id))
                .font(.headline)
                .lineLimit(1)

            VStack(spacing: 0) {
                ForEach(section.entries, id: \.self) { entryID in
                    entryRow(entryID, column: column)
                    if entryID != section.entries.last {
                        Divider()
                            .padding(
                                .leading,
                                HelpCheatSheetLayoutEngine.horizontalPadding + column.nameWidth + HelpCheatSheetLayoutEngine.columnSpacing
                            )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35))
            )
        }
    }

    private func entryRow(_ entryID: String, column: HelpCheatSheetColumnLayout) -> some View {
        let shortcut = L10n.Help.entryShortcut(entryID)
        return HStack(alignment: .firstTextBaseline, spacing: HelpCheatSheetLayoutEngine.columnSpacing) {
            Text(L10n.Help.entryName(entryID))
                .font(.body.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: column.nameWidth, alignment: .leading)
            Text(L10n.Help.entryDescription(entryID))
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: column.descriptionWidth, alignment: .leading)
            Text(shortcut.isEmpty ? L10n.Help.noShortcut : shortcut)
                .font(.caption.monospaced())
                .foregroundStyle(shortcut.isEmpty ? .tertiary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: column.shortcutWidth, alignment: .trailing)
        }
        .padding(.horizontal, HelpCheatSheetLayoutEngine.horizontalPadding)
        .padding(.vertical, 8)
    }
}
