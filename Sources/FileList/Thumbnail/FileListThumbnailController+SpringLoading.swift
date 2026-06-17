import AppKit
import Foundation

extension FileListThumbnailController {
    static let springLoadingDelay: TimeInterval = 0.5
    
    func handleSpringLoadingHover(at indexPath: IndexPath?) {
        guard let indexPath,
              indexPath.item >= 0,
              indexPath.item < displayRows.count else {
            cancelSpringLoading()
            return
        }
        
        let row = displayRows[indexPath.item]
        guard row.isDirectory,
              !row.isParentDirectoryEntry,
              interaction.dropDestinationPath(row) != nil else {
            cancelSpringLoading()
            return
        }
        
        if springLoadTargetIndexPath == indexPath, springLoadWorkItem != nil {
            return
        }
        
        cancelSpringLoading()
        springLoadTargetIndexPath = indexPath
        let work = DispatchWorkItem { [weak self] in
            self?.performSpringLoading()
        }
        springLoadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.springLoadingDelay, execute: work)
    }
    
    func cancelSpringLoading() {
        springLoadWorkItem?.cancel()
        springLoadWorkItem = nil
        springLoadTargetIndexPath = nil
    }
    
    func springLoadingIndexPath(at pointInCollectionView: NSPoint) -> IndexPath? {
        guard let collectionView else { return nil }
        guard let indexPath = collectionView.indexPathForItem(at: pointInCollectionView),
              indexPath.item >= 0,
              indexPath.item < displayRows.count else {
            return nil
        }
        let row = displayRows[indexPath.item]
        guard row.isDirectory,
              !row.isParentDirectoryEntry,
              interaction.dropDestinationPath(row) != nil else {
            return nil
        }
        return indexPath
    }
    
    private func performSpringLoading() {
        guard let indexPath = springLoadTargetIndexPath,
              indexPath.item >= 0,
              indexPath.item < displayRows.count else {
            cancelSpringLoading()
            return
        }
        let row = displayRows[indexPath.item]
        cancelSpringLoading()
        onOpenRow?(row)
    }
}
