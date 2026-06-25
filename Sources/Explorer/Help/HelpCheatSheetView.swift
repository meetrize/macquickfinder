import SwiftUI

struct HelpCheatSheetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            columnHeaders
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(HelpCheatSheetContent.sections) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Help.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var columnHeaders: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(L10n.Help.columnFeature)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)
            Text(L10n.Help.columnDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.Help.columnShortcut)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func sectionBlock(_ section: HelpCheatSheetSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Help.sectionTitle(section.id))
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(section.entries, id: \.self) { entryID in
                    entryRow(entryID)
                    if entryID != section.entries.last {
                        Divider()
                            .padding(.leading, 120)
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

    private func entryRow(_ entryID: String) -> some View {
        let shortcut = L10n.Help.entryShortcut(entryID)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(L10n.Help.entryName(entryID))
                .font(.body.weight(.medium))
                .frame(width: 108, alignment: .leading)
            Text(L10n.Help.entryDescription(entryID))
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortcut.isEmpty ? L10n.Help.noShortcut : shortcut)
                .font(.caption.monospaced())
                .foregroundStyle(shortcut.isEmpty ? .tertiary : .secondary)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
