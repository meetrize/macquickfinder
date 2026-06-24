import AppKit
import Foundation

/// 拖放目标解析：行目录 vs 当前目录（列表/缩略图共用）。
enum FileListDropTargetResolver {
    struct Resolution {
        let rowIndex: Int?
        let destinationPath: String
    }

    static func resolve(
        displayRows: [FileListRow],
        rowIndex: Int?,
        interaction: FileListTableInteraction,
        urls: [URL]
    ) -> Resolution? {
        if let rowIndex,
           rowIndex >= 0,
           rowIndex < displayRows.count {
            let row = displayRows[rowIndex]
            if let destinationPath = interaction.dropDestinationPath(row),
               interaction.canAcceptDrop(destinationPath, urls) {
                return Resolution(rowIndex: rowIndex, destinationPath: destinationPath)
            }
        }

        if let currentPath = interaction.currentDirectoryDropPath,
           interaction.canAcceptDrop(currentPath, urls) {
            return Resolution(rowIndex: nil, destinationPath: currentPath)
        }

        return nil
    }

    static func dragOperation(from draggingInfo: NSDraggingInfo) -> NSDragOperation {
        FileListDragSupport.shouldCopy(from: draggingInfo) ? .copy : .move
    }

    static func urls(from draggingInfo: NSDraggingInfo) -> [URL] {
        FileListDragSupport.fileURLs(from: draggingInfo.draggingPasteboard)
    }
}
