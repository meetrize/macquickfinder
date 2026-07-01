import SwiftUI

/// 列表/缩略图 Host 共用的 Coordinator 绑定。
enum FileListContentHostSupport {
    static func wireCallbacks<C: FileListContentController>(
        _ controller: C,
        onOpenRow: @escaping (FileListRowOpenIntent) -> Void,
        onVisibleDirectoryPathsChanged: (([String]) -> Void)?
    ) {
        controller.onOpenRow = onOpenRow
        controller.onVisibleDirectoryPathsChanged = onVisibleDirectoryPathsChanged
    }

    static func applyListingUpdate<C: FileListContentController>(
        _ controller: C,
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selection: Binding<Set<String>>,
        preferencesStore: FileListPreferencesStore,
        metadataProviders: FileListDirectoryMetadataRefresh.Providers,
        apply: (C, FileListContentController.ListingUpdatePlan) -> Void
    ) {
        controller.bindUpdateContext(
            interaction: interaction,
            selectionGet: { selection.wrappedValue },
            selectionSet: { selection.wrappedValue = $0 },
            preferencesStore: preferencesStore
        )
        let plan = controller.prepareListingUpdate(
            rows: rows,
            metadataProviders: metadataProviders
        )
        apply(controller, plan)
    }
}
