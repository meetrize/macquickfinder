import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewArchiveToolbarItems() -> [PreviewToolbarOverflowModel] {
        let hasSelection = !archive.selectedEntryPaths.isEmpty
        return [
            previewToolbarIconItem(
                id: "archive-reload",
                title: L10n.Preview.Toolbar.refreshListing,
                systemImage: "arrow.clockwise",
                action: { [self] in archive.reloadToken += 1 }
            ),
            previewToolbarIconItem(
                id: "archive-expand",
                title: archive.expanded ? L10n.Preview.Toolbar.archiveCollapse : L10n.Preview.Toolbar.archiveExpand,
                systemImage: archive.expanded ? "chevron.down" : "chevron.right",
                action: { [self] in archive.expanded.toggle() }
            ),
            previewToolbarIconItem(
                id: "archive-copy",
                title: L10n.Preview.Toolbar.copyManifest,
                systemImage: "doc.on.doc",
                action: { [self] in archive.copyAction = .copyList }
            ),
            previewToolbarIconItem(
                id: "archive-extract-selected",
                title: L10n.Preview.Toolbar.extractSelected,
                systemImage: "arrow.up.bin.fill",
                isDisabled: !hasSelection,
                action: { [self] in archive.extractAction = .extractSelectedHere }
            ),
            previewToolbarIconItem(
                id: "archive-extract-selected-to",
                title: L10n.Preview.Toolbar.extractSelectedTo,
                systemImage: "folder.badge.plus",
                isDisabled: !hasSelection,
                action: { [self] in archive.extractAction = .extractSelectedTo }
            ),
            previewToolbarIconItem(
                id: "archive-extract",
                title: L10n.Preview.Toolbar.extract,
                systemImage: "arrow.up.bin",
                action: { [self] in archive.extractAction = .extractHere }
            ),
            previewToolbarIconItem(
                id: "archive-extract-to",
                title: L10n.Preview.Toolbar.extractTo,
                systemImage: "folder",
                action: { [self] in archive.extractAction = .extractTo }
            ),
        ]
    }
}
