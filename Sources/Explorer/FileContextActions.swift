import Foundation
import FileList

struct FileContextActions {
    var open: (FileItem) -> Void = { _ in }
    var openInDetachedPreview: (FileItem) -> Void = { _ in }
    var canOpenInDetachedPreview: (FileItem) -> Bool = { _ in false }
    var openWith: (FileItem) -> Void = { _ in }
    var openWithApplication: ([FileItem], URL) -> Void = { _, _ in }
    var cut: ([FileItem]) -> Void = { _ in }
    var copy: ([FileItem]) -> Void = { _ in }
    var copyFilename: (FileItem) -> Void = { _ in }
    var copyPaths: ([FileItem]) -> Void = { _ in }
    var delete: ([FileItem]) -> Void = { _ in }
    var rename: (FileItem) -> Void = { _ in }
    var showInfo: ([FileItem]) -> Void = { _ in }
    var showFinderInfo: ([FileItem]) -> Void = { _ in }
    var canPaste: (String) -> Bool = { _ in false }
    var paste: (String) -> Void = { _ in }
    var isFavorited: (FileItem) -> Bool = { _ in false }
    var addToFavorites: (FileItem) -> Void = { _ in }
    var isInTrash: Bool = false
    var canEmptyTrash: Bool = false
    var emptyTrash: () -> Void = {}
    var putBack: ([FileItem]) -> Void = { _ in }
    var deleteImmediately: ([FileItem]) -> Void = { _ in }
    var openTerminal: (FileItem) -> Void = { _ in }
    var openInNewWindow: (FileItem) -> Void = { _ in }
    var showRefresh = false
    var refresh: () -> Void = {}
    var compress: ([FileItem]) -> Void = { _ in }
    var extractHere: ([FileItem]) -> Void = { _ in }
    var extractTo: ([FileItem]) -> Void = { _ in }
    var extractToDownloads: ([FileItem]) -> Void = { _ in }
}



