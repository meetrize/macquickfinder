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
        } else {
            HStack(spacing: ExplorerToolbarMetrics.iconSpacing) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { _, entry in
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
