import Foundation

enum RecordedOperationSummary {
    static func title(for operation: RecordedOperation) -> String {
        switch operation {
        case .copy(let sources):
            return L10n.OperationRecording.stepCopy(sources.count)
        case .cut(let sources):
            return L10n.OperationRecording.stepCut(sources.count)
        case .paste(let pairs, let mode):
            let destination = pairs.first?.destination.deletingLastPathComponent().lastPathComponent ?? ""
            switch mode {
            case .copy:
                return L10n.OperationRecording.stepPasteCopy(pairs.count, destination)
            case .move:
                return L10n.OperationRecording.stepPasteMove(pairs.count, destination)
            }
        case .transferItems(let pairs, let mode):
            let destination = pairs.first?.destination.deletingLastPathComponent().lastPathComponent ?? ""
            switch mode {
            case .copy:
                return L10n.OperationRecording.stepDragCopy(pairs.count, destination)
            case .move:
                return L10n.OperationRecording.stepDragMove(pairs.count, destination)
            }
        case .trash(let urls):
            return L10n.OperationRecording.stepTrash(urls.count)
        case .deleteImmediately(let urls):
            return L10n.OperationRecording.stepDeleteImmediately(urls.count)
        case .rename(_, let destination):
            return L10n.OperationRecording.stepRename(destination.lastPathComponent)
        case .createDirectory(let url):
            return L10n.OperationRecording.stepCreateDirectory(url.lastPathComponent)
        case .createFile(let url):
            return L10n.OperationRecording.stepCreateFile(url.lastPathComponent)
        case .compress(let sources, let archive, _):
            return L10n.OperationRecording.stepCompress(sources.count, archive.lastPathComponent)
        case .extract(let archive, let destination, _):
            return L10n.OperationRecording.stepExtract(archive.lastPathComponent, destination.lastPathComponent)
        }
    }

    static func shortTitle(for operation: RecordedOperation) -> String {
        switch operation {
        case .copy, .cut:
            return L10n.OperationRecording.shortClipboard
        case .paste(_, let mode), .transferItems(_, let mode):
            return mode == .copy
                ? L10n.OperationRecording.shortCopy
                : L10n.OperationRecording.shortMove
        case .trash, .deleteImmediately:
            return L10n.OperationRecording.shortDelete
        case .rename:
            return L10n.OperationRecording.shortRename
        case .createDirectory:
            return L10n.OperationRecording.shortNewFolder
        case .createFile:
            return L10n.OperationRecording.shortNewFile
        case .compress:
            return L10n.OperationRecording.shortCompress
        case .extract:
            return L10n.OperationRecording.shortExtract
        }
    }
}
