import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewArchiveToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "archive-reload",
                title: "刷新目录",
                systemImage: "arrow.clockwise",
                action: { [self] in archive.reloadToken += 1 }
            ),
            previewToolbarIconItem(
                id: "archive-expand",
                title: archive.expanded ? "折叠到第一层" : "展开到全部层级",
                systemImage: archive.expanded ? "chevron.down" : "chevron.right",
                action: { [self] in archive.expanded.toggle() }
            ),
            previewToolbarIconItem(
                id: "archive-copy",
                title: "复制清单",
                systemImage: "doc.on.doc",
                action: { [self] in archive.copyAction = .copyList }
            ),
        ]
    }
}
