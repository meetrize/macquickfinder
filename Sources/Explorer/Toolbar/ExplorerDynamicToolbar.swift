import SwiftUI

struct ExplorerDynamicToolbar<SearchContent: View>: ToolbarContent {
    @ObservedObject var store: ToolbarCustomizationStore
    let environment: ExplorerToolbarEnvironment
  @ViewBuilder let searchContent: () -> SearchContent

    private var activeLayout: ToolbarLayoutConfig {
        store.workingLayout
    }

    var body: some ToolbarContent {
        if activeLayout.items(in: .leading).isEmpty == false || store.isCustomizing {
            ToolbarItem(id: "toolbar.leading", placement: .navigation) {
                zoneStrip(.leading)
            }
            .hideSharedBackgroundIfAvailable()
        }

        if activeLayout.items(in: .main).isEmpty == false || store.isCustomizing {
            ToolbarItem(id: "toolbar.main", placement: .primaryAction) {
                zoneStrip(.main)
            }
            .hideSharedBackgroundIfAvailable()
        }

        if activeLayout.items(in: .trailing).isEmpty == false || store.isCustomizing {
            ToolbarItem(id: "toolbar.trailing", placement: .primaryAction) {
                zoneStrip(.trailing)
            }
            .hideSharedBackgroundIfAvailable()
        }

        ToolbarItem(id: "toolbar.search", placement: .primaryAction) {
            searchContent()
                .opacity(store.isCustomizing ? 0.45 : 1)
                .allowsHitTesting(!store.isCustomizing)
        }
        .hideSharedBackgroundIfAvailable()
    }

    @ViewBuilder
    private func zoneStrip(_ zone: ToolbarZone) -> some View {
        let entries = activeLayout.items(in: zone)

        if store.isCustomizing {
            ToolbarCustomizationZoneStrip(
                zone: zone,
                entries: entries,
                store: store
            ) { entry, _ in
                toolbarCell(entry: entry)
            }
        } else if zone == .main {
            mainZoneStrip(entries: entries)
        } else if zone == .leading {
            leadingZoneStrip(entries: entries)
        } else {
            HStack(spacing: ExplorerToolbarMetrics.iconSpacing) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { _, entry in
                    toolbarCell(entry: entry)
                }
            }
        }
    }

    @ViewBuilder
    private func leadingZoneStrip(entries: [ToolbarVisibleEntry]) -> some View {
        let fileActionIDs = Set([
            ToolbarBuiltinID.newFile.rawValue,
            ToolbarBuiltinID.newFolder.rawValue,
            ToolbarBuiltinID.delete.rawValue,
        ])
        let fileActions = ToolbarMainGroup.sortedEntries(
            entries.filter { fileActionIDs.contains($0.id) }
        )
        let rest = entries.filter { !fileActionIDs.contains($0.id) }

        HStack(spacing: ExplorerToolbarMetrics.iconSpacing) {
            ForEach(fileActions) { entry in
                toolbarCell(entry: entry)
            }
            if !fileActions.isEmpty, !rest.isEmpty {
                ToolbarGroupDivider()
            }
            ForEach(rest) { entry in
                toolbarCell(entry: entry)
            }
        }
    }

    @ViewBuilder
    private func mainZoneStrip(entries: [ToolbarVisibleEntry]) -> some View {
        let groups = ToolbarMainGroup.groupedEntries(entries)
        HStack(spacing: ExplorerToolbarMetrics.iconSpacing) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, groupEntries in
                if index > 0 {
                    ToolbarGroupDivider()
                }
                ForEach(groupEntries) { entry in
                    toolbarCell(entry: entry)
                }
            }
        }
    }

    @ViewBuilder
    private func toolbarCell(entry: ToolbarVisibleEntry) -> some View {
        if store.isCustomizing {
            ToolbarDraggableChip(
                itemID: entry.id,
                kind: entry.kind,
                source: .toolbar
            ) {
                ToolbarItemChipLabel(
                    entry: entry,
                    layout: activeLayout,
                    environment: environment
                )
            }
            .overlay {
                ToolbarItemFrameReporter(itemID: entry.id)
                    .frame(
                        width: ExplorerToolbarMetrics.iconHitSize,
                        height: ExplorerToolbarMetrics.iconHitSize
                    )
                    .allowsHitTesting(false)
            }
        } else {
            ExplorerToolbarItemView(
                entry: entry,
                layout: activeLayout,
                environment: environment
            )
        }
    }
}
