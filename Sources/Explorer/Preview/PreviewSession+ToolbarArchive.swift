import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewArchiveToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
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
        ]
    }
}
