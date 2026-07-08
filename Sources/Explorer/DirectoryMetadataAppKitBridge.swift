import FileList
import Foundation

/// 将 `DirectoryMetadataOverlay` revision 订阅下沉到 AppKit 控制器，避免 SwiftUI `body` 随元数据刷新。
@MainActor
final class DirectoryMetadataAppKitBridge {
    static let shared = DirectoryMetadataAppKitBridge()

    private var sizeHandlerID: UUID?
    private var countHandlerID: UUID?
    private var installedOverlay: DirectoryMetadataOverlay?

    private init() {}

    func installIfNeeded(overlay: DirectoryMetadataOverlay) {
        if installedOverlay === overlay, sizeHandlerID != nil {
            return
        }
        if let sizeHandlerID, let installedOverlay {
            installedOverlay.removeSizeRevisionHandler(sizeHandlerID)
        }
        if let countHandlerID, let installedOverlay {
            installedOverlay.removeCountRevisionHandler(countHandlerID)
        }

        installedOverlay = overlay
        sizeHandlerID = overlay.addSizeRevisionHandler { revision in
            let provider = DirectorySizeColumnProvider(
                revision: revision,
                display: { overlay.sizeDisplay(for: $0) }
            )
            FileListTableController.shared?.refreshDirectorySizeColumnIfNeeded(provider)
            FileListThumbnailController.shared?.refreshDirectorySizeColumnIfNeeded(provider)
        }
        countHandlerID = overlay.addCountRevisionHandler { revision in
            let provider = DirectoryItemCountColumnProvider(
                revision: revision,
                display: { overlay.countDisplay(for: $0) }
            )
            FileListThumbnailController.shared?.refreshDirectoryItemCountColumnIfNeeded(provider)
        }
    }
}
