import AppKit
import Foundation
import FileList
import UniformTypeIdentifiers

enum FileOperations {
    private static let finderCopyPasteboardType = NSPasteboard.PasteboardType("com.apple.finder.copy")
    
    struct PasteboardState {
        let urls: [URL]
        let isCut: Bool
    }
    
    static func pasteboardState() -> PasteboardState {
        let pasteboard = NSPasteboard.general
        let urls = readFileURLs(from: pasteboard)
        let isCut = pasteboard.types?.contains(finderCopyPasteboardType) == true
        return PasteboardState(urls: urls, isCut: isCut)
    }
    
    static func pasteDestination(selectedItems: [FileItem], currentDirectoryPath: String) -> String {
        if selectedItems.count == 1,
           let item = selectedItems.first,
           item.isDirectory {
            return item.url.path
        }
        return currentDirectoryPath
    }
    
    static func canPaste(to destinationDirectory: URL) -> Bool {
        canPaste(with: pasteboardState(), to: destinationDirectory)
    }

    static func canPaste(
        with state: PasteboardState,
        to destinationDirectory: URL,
        hasCreatableContent: Bool? = nil
    ) -> Bool {
        if !state.urls.isEmpty {
            return canMoveItems(
                state.urls,
                to: destinationDirectory,
                allowSameDirectory: !state.isCut
            )
        }
        let canCreate = hasCreatableContent ?? (ClipboardFileCreation.contentKind() != nil)
        guard canCreate else { return false }
        return ClipboardFileCreation.canCreateFile(in: destinationDirectory, assumingContentAvailable: true)
    }
    
    static func canMoveItems(
        _ sourceURLs: [URL],
        to destinationDirectory: URL,
        allowSameDirectory: Bool = false
    ) -> Bool {
        if allowSameDirectory {
            let destURL = destinationDirectory.standardizedFileURL
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: destURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return false
            }
            for sourceURL in sourceURLs {
                guard FileManager.default.fileExists(atPath: sourceURL.standardizedFileURL.path) else {
                    return false
                }
            }
            return true
        }
        return moveBlockReason(for: sourceURLs, to: destinationDirectory) == nil
    }

    static func presentMoveBlockedAlert(_ reason: FavoritePathNormalization.MoveBlockReason) {
        let alert = NSAlert()
        alert.messageText = L10n.Alert.moveBlockedTitle
        alert.informativeText = L10n.Alert.moveBlockedMessage(reason)
        alert.alertStyle = .warning
        alert.runModal()
    }

    private static func moveBlockReason(
        for sourceURLs: [URL],
        to destinationDirectory: URL
    ) -> FavoritePathNormalization.MoveBlockReason? {
        FavoritePathNormalization.moveBlockReason(
            moving: sourceURLs.map { $0.standardizedFileURL.path },
            to: destinationDirectory.standardizedFileURL.path
        )
    }
    
    static func moveItems(
        _ sourceURLs: [URL],
        to destinationDirectory: URL,
        copy: Bool,
        completion: @escaping () -> Void
    ) {
        if let reason = moveBlockReason(for: sourceURLs, to: destinationDirectory) {
            presentMoveBlockedAlert(reason)
            return
        }
        
        let fileManager = FileManager.default
        var hadError = false
        var completedPairs: [RecordedFilePair] = []
        
        for sourceURL in sourceURLs {
            let destinationURL = uniqueDestinationURL(
                for: sourceURL.lastPathComponent,
                in: destinationDirectory
            )
            
            do {
                if copy {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                } else {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                }
                completedPairs.append(RecordedFilePair(source: sourceURL, destination: destinationURL))
            } catch {
                NSAlert(error: error).runModal()
                hadError = true
                break
            }
        }
        
        if !hadError {
            recordOperation(
                .transferItems(
                    pairs: completedPairs,
                    mode: copy ? .copy : .move
                )
            )
            if let firstDestination = completedPairs.first?.destination {
                notifyGitWorkingTreeIfNeeded(at: firstDestination)
            }
            completion()
        }
    }
    
    static func trashItems(_ sourceURLs: [URL], completion: @escaping () -> Void) {
        var hadError = false
        for sourceURL in sourceURLs {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: sourceURL, resultingItemURL: &resultingURL)
                TrashRestoreStore.recordTrash(
                    source: sourceURL,
                    resultingTrashedURL: resultingURL as URL?
                )
            } catch {
                NSAlert(error: error).runModal()
                hadError = true
                break
            }
        }
        if !hadError {
            recordOperation(.trash(urls: sourceURLs))
            if let firstURL = sourceURLs.first {
                notifyGitWorkingTreeIfNeeded(at: firstURL)
            }
            completion()
        }
    }
    
    static func emptyTrash(completion: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = L10n.Alert.emptyTrashTitle
        alert.informativeText = L10n.Alert.emptyTrashMessage
        alert.alertStyle = .warning
        let emptyButton = alert.addButton(withTitle: L10n.Action.emptyTrash)
        alert.addButton(withTitle: L10n.Action.cancel)
        alert.window.initialFirstResponder = emptyButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let script = """
        tell application "Finder"
            empty trash
        end tell
        """
        if runFinderAppleScript(script) {
            TrashRestoreStore.removeAllRecords()
            completion()
        }
    }
    
    static func putBack(_ items: [FileItem], completion: @escaping () -> Void) {
        guard !items.isEmpty else { return }
        
        var restoredCount = 0
        var failedItems: [FileItem] = []
        
        for item in items {
            if restoreItem(item) {
                restoredCount += 1
            } else {
                failedItems.append(item)
            }
        }
        
        if failedItems.isEmpty {
            if let firstItem = items.first {
                notifyGitWorkingTreeIfNeeded(at: firstItem.url)
            }
            completion()
            return
        }
        
        if restoredCount > 0 {
            if let firstItem = items.first {
                notifyGitWorkingTreeIfNeeded(at: firstItem.url)
            }
            completion()
        }
        
        let alert = NSAlert()
        if failedItems.count == 1 {
            alert.messageText = L10n.Alert.putBackFailedTitle
            alert.informativeText = L10n.Alert.putBackFailedSingle(failedItems[0].name)
        } else {
            alert.messageText = L10n.Alert.putBackFailedTitle
            alert.informativeText = L10n.Alert.putBackFailedMultiple(failedItems.count)
        }
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private static func restoreItem(_ item: FileItem) -> Bool {
        let escapedPath = appleScriptEscapedPath(item.url.path)
        let finderScript = """
        tell application "Finder"
            put (POSIX file "\(escapedPath)") back
        end tell
        """
        if runFinderAppleScript(finderScript, showError: false) {
            TrashRestoreStore.removeRecord(forTrashedPath: item.url.path)
            return true
        }
        
        guard let record = TrashRestoreStore.record(forTrashedPath: item.url.path) else {
            return false
        }
        
        let destinationDirectory = URL(fileURLWithPath: record.originalDirectory, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        let destinationURL = uniqueDestinationURL(for: record.originalName, in: destinationDirectory)
        do {
            try FileManager.default.moveItem(at: item.url, to: destinationURL)
            TrashRestoreStore.removeRecord(forTrashedPath: item.url.path)
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }
    
    static func deleteImmediately(_ items: [FileItem], completion: @escaping () -> Void) {
        guard !items.isEmpty else { return }
        
        let alert = NSAlert()
        if items.count == 1 {
            alert.messageText = L10n.Alert.deleteImmediatelySingle(items[0].name)
        } else {
            alert.messageText = L10n.Alert.deleteImmediatelyMultiple(items.count)
        }
        alert.informativeText = L10n.Alert.deleteImmediatelyMessage
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: L10n.Action.deleteImmediately)
        alert.addButton(withTitle: L10n.Action.cancel)
        alert.window.initialFirstResponder = deleteButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let urls = items.map(\.url)
        for item in items {
            do {
                try FileManager.default.removeItem(at: item.url)
                TrashRestoreStore.removeRecord(forTrashedPath: item.url.path)
            } catch {
                NSAlert(error: error).runModal()
                return
            }
        }
        recordOperation(.deleteImmediately(urls: urls))
        if let firstURL = urls.first {
            notifyGitWorkingTreeIfNeeded(at: firstURL)
        }
        completion()
    }
    
    private static func runFinderAppleScript(_ source: String, showError: Bool = true) -> Bool {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        _ = script.executeAndReturnError(&error)
        
        if let error {
            guard showError else { return false }
            let message = error[NSAppleScript.errorMessage] as? String ?? L10n.Alert.operationFailed
            let alert = NSAlert()
            alert.messageText = L10n.Alert.operationFailed
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }
        return true
    }
    
    private static func appleScriptEscapedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    static func paste(
        to destinationDirectory: URL,
        completion: @escaping (_ createdContentFileURL: URL?) -> Void
    ) {
        let state = pasteboardState()
        guard canPaste(with: state, to: destinationDirectory) else { return }

        if state.urls.isEmpty {
            guard let createdURL = ClipboardFileCreation.createFile(in: destinationDirectory) else { return }
            recordOperation(.createFile(url: createdURL))
            notifyGitWorkingTreeIfNeeded(at: createdURL)
            completion(createdURL)
            return
        }

        let fileManager = FileManager.default
        var hadError = false
        var completedPairs: [RecordedFilePair] = []

        for sourceURL in state.urls {
            let destinationURL = uniqueDestinationURL(
                for: sourceURL.lastPathComponent,
                in: destinationDirectory
            )

            do {
                if state.isCut {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                } else {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
                completedPairs.append(RecordedFilePair(source: sourceURL, destination: destinationURL))
            } catch {
                NSAlert(error: error).runModal()
                hadError = true
                break
            }
        }

        if state.isCut && !hadError {
            clearCutPasteboard()
        }
        if !hadError {
            recordOperation(
                .paste(
                    pairs: completedPairs,
                    mode: state.isCut ? .move : .copy
                )
            )
            if let firstDestination = completedPairs.first?.destination {
                notifyGitWorkingTreeIfNeeded(at: firstDestination)
            }
            completion(nil)
        }
    }
    
    static func open(_ items: [FileItem], onNavigate: (String) -> Void) {
        guard let first = items.first else { return }

        if items.count == 1 {
            if first.isApplicationBundle {
                NSWorkspace.shared.open(first.url)
            } else if first.isDirectory {
                onNavigate(first.url.path)
            } else {
                NSWorkspace.shared.open(first.url)
            }
            return
        }
        
        for item in items where !item.isDirectory || item.isApplicationBundle {
            NSWorkspace.shared.open(item.url)
        }
        if let directory = items.first(where: { $0.isDirectory && !$0.isApplicationBundle }) {
            onNavigate(directory.url.path)
        }
    }
    
    static func openWith(_ item: FileItem) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application, .applicationBundle]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = L10n.Alert.openWithChooseApp(item.name)
        panel.prompt = L10n.Alert.openWithPrompt
        
        guard panel.runModal() == .OK, let appURL = panel.url else { return }
        
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([item.url], withApplicationAt: appURL, configuration: configuration)
    }

    static func openWithApplication(_ items: [FileItem], appURL: URL) {
        let urls = items.filter { !$0.isDirectory }.map(\.url)
        guard !urls.isEmpty else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration)
    }
    
    static func cut(_ items: [FileItem]) {
        let urls = items.map(\.url)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        pasteboard.setPropertyList(
            urls.map(\.path),
            forType: finderCopyPasteboardType
        )
        recordOperation(.cut(sources: urls))
    }
    
    static func copy(_ items: [FileItem]) {
        let urls = items.map(\.url)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        recordOperation(.copy(sources: urls))
    }
    
    static func copyFilename(_ item: FileItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.name, forType: .string)
    }
    
    static func copyPaths(_ items: [FileItem]) {
        let paths = items.map(\.url.path).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths, forType: .string)
    }
    
    static func delete(_ items: [FileItem], completion: @escaping () -> Void) {
        let alert = NSAlert()
        if items.count == 1 {
            alert.messageText = L10n.Alert.confirmDeleteSingle(items[0].name)
        } else {
            alert.messageText = L10n.Alert.confirmDeleteMultiple(items.count)
        }
        alert.informativeText = L10n.Alert.deleteToTrashMessage
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: L10n.Action.delete)
        alert.addButton(withTitle: L10n.Action.cancel)
        alert.window.initialFirstResponder = deleteButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let urls = items.map(\.url)
        for item in items {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
                TrashRestoreStore.recordTrash(
                    source: item.url,
                    resultingTrashedURL: resultingURL as URL?
                )
            } catch {
                NSAlert(error: error).runModal()
                return
            }
        }
        recordOperation(.trash(urls: urls))
        if let firstURL = urls.first {
            notifyGitWorkingTreeIfNeeded(at: firstURL)
        }
        completion()
    }
    
    @discardableResult
    static func moveItem(_ item: FileItem, toNewName newName: String) -> Result<URL, Error> {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteInvalidFileNameError,
                userInfo: [NSLocalizedDescriptionKey: L10n.Error.emptyName]
            ))
        }
        guard trimmed != item.name else {
            return .success(item.url)
        }
        
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            recordOperation(.rename(source: item.url, destination: newURL))
            notifyGitWorkingTreeIfNeeded(at: newURL)
            return .success(newURL)
        } catch {
            return .failure(error)
        }
    }
    
    static func showInfo(_ items: [FileItem]) {
        Task { @MainActor in
            FilePropertiesWindowController.show(items: items)
        }
    }
    
    private static func buildInfoText(for item: FileItem) -> String {
        var lines: [String] = []
        
        if item.isDirectory {
            lines.append(L10n.Info.kindFolder)
        } else if item.url.pathExtension.isEmpty {
            lines.append(L10n.Info.kindFile)
        } else {
            lines.append(L10n.Info.kindExtensionFile(item.url.pathExtension.uppercased()))
        }
        
        lines.append(L10n.Info.size(item.sizeDisplay))
        lines.append(L10n.Info.location(item.url.deletingLastPathComponent().path))
        
        let keys: Set<URLResourceKey> = [
            .creationDateKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .isReadableKey,
            .isWritableKey,
            .isExecutableKey,
            .typeIdentifierKey
        ]
        
        if let values = try? item.url.resourceValues(forKeys: keys) {
            if let created = values.creationDate {
                lines.append(L10n.Info.created(FileItemFormatters.formatDate(created)))
            }
            lines.append(L10n.Info.modified(item.dateDisplay))
            lines.append(L10n.Info.hidden(item.isHidden))
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: item.url.path),
               let permissions = attributes[.posixPermissions] as? Int {
                lines.append(
                    L10n.Info.permissions(
                        posixPermissionString(permissions),
                        String(format: "%04o", permissions)
                    )
                )
            }
            
            var access: [String] = []
            if values.isReadable == true { access.append(L10n.Info.accessReadable) }
            if values.isWritable == true { access.append(L10n.Info.accessWritable) }
            if values.isExecutable == true { access.append(L10n.Info.accessExecutable) }
            if !access.isEmpty {
                lines.append("\(L10n.Info.accessLabel)\(access.joined(separator: ", "))")
            }
            
            if let typeIdentifier = values.typeIdentifier {
                lines.append(L10n.Info.typeIdentifier(typeIdentifier))
            }
        }
        
        lines.append(L10n.Info.path(item.url.path))
        return lines.joined(separator: "\n")
    }
    
    private static func posixPermissionString(_ permissions: Int) -> String {
        let mode = permissions & 0o777
        let symbols = ["r", "w", "x"]
        var result = ""
        for shift in stride(from: 6, through: 0, by: -3) {
            for (index, symbol) in symbols.enumerated() {
                let bit = 1 << (shift + (2 - index))
                result += (mode & bit) != 0 ? symbol : "-"
            }
        }
        return result
    }
    
    private static func readFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            return []
        }
        return objects.map(\.standardizedFileURL)
    }
    
    private static func uniqueDestinationURL(for name: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        
        let baseName = (name as NSString).deletingPathExtension
        let pathExtension = (name as NSString).pathExtension
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let newName: String
            if pathExtension.isEmpty {
                newName = "\(baseName) \(counter)"
            } else {
                newName = "\(baseName) \(counter).\(pathExtension)"
            }
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
    
    private static func clearCutPasteboard() {
        NSPasteboard.general.clearContents()
    }

    private static func recordOperation(_ operation: RecordedOperation) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                OperationRecordingHub.record(operation)
            }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    OperationRecordingHub.record(operation)
                }
            }
        }
    }

    private static func notifyGitWorkingTreeIfNeeded(at url: URL) {
        GitWorkingTreeRefreshCenter.notifyWorkingTreeMayHaveChanged(at: url.path)
    }
}
