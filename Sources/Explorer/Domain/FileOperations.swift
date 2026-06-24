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
        let state = pasteboardState()
        guard !state.urls.isEmpty else { return false }
        return canMoveItems(
            state.urls,
            to: destinationDirectory,
            allowSameDirectory: !state.isCut
        )
    }
    
    static func canMoveItems(
        _ sourceURLs: [URL],
        to destinationDirectory: URL,
        allowSameDirectory: Bool = false
    ) -> Bool {
        let destURL = destinationDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        let destPath = destURL.path
        for sourceURL in sourceURLs {
            let srcURL = sourceURL.standardizedFileURL
            guard FileManager.default.fileExists(atPath: srcURL.path) else { return false }
            
            let srcPath = srcURL.path
            if srcPath == destPath { return false }
            if destPath.hasPrefix(srcPath + "/") { return false }
            if !allowSameDirectory,
               srcURL.deletingLastPathComponent().standardizedFileURL.path == destPath {
                return false
            }
        }
        return true
    }
    
    static func moveItems(
        _ sourceURLs: [URL],
        to destinationDirectory: URL,
        copy: Bool,
        completion: @escaping () -> Void
    ) {
        guard canMoveItems(sourceURLs, to: destinationDirectory) else { return }
        
        let fileManager = FileManager.default
        var hadError = false
        
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
            } catch {
                NSAlert(error: error).runModal()
                hadError = true
                break
            }
        }
        
        if !hadError {
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
            completion()
        }
    }
    
    static func emptyTrash(completion: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "清倒废纸篓？"
        alert.informativeText = "废纸篓中的所有项目将被永久删除，此操作无法撤销。"
        alert.alertStyle = .warning
        let emptyButton = alert.addButton(withTitle: "清倒废纸篓")
        alert.addButton(withTitle: "取消")
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
            completion()
            return
        }
        
        if restoredCount > 0 {
            completion()
        }
        
        let alert = NSAlert()
        if failedItems.count == 1 {
            alert.messageText = "无法放回原处"
            alert.informativeText = "「\(failedItems[0].name)」没有可用的原始位置记录，且 Finder 无法恢复此项目。"
        } else {
            alert.informativeText = "\(failedItems.count) 个项目无法放回原处。"
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
            alert.messageText = "立刻删除「\(items[0].name)」？"
        } else {
            alert.messageText = "立刻删除 \(items.count) 个项目？"
        }
        alert.informativeText = "这些项目将被永久删除，无法恢复。"
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "立刻删除")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = deleteButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        for item in items {
            do {
                try FileManager.default.removeItem(at: item.url)
                TrashRestoreStore.removeRecord(forTrashedPath: item.url.path)
            } catch {
                NSAlert(error: error).runModal()
                return
            }
        }
        completion()
    }
    
    private static func runFinderAppleScript(_ source: String, showError: Bool = true) -> Bool {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        _ = script.executeAndReturnError(&error)
        
        if let error {
            guard showError else { return false }
            let message = error[NSAppleScript.errorMessage] as? String ?? "操作失败"
            let alert = NSAlert()
            alert.messageText = "操作失败"
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
    
    static func paste(to destinationDirectory: URL, completion: @escaping () -> Void) {
        let state = pasteboardState()
        guard canPaste(to: destinationDirectory) else { return }
        
        let fileManager = FileManager.default
        var hadError = false
        
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
            completion()
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
        panel.message = "选择用于打开「\(item.name)」的应用"
        panel.prompt = "打开"
        
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
    }
    
    static func copy(_ items: [FileItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map(\.url) as [NSURL])
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
            alert.messageText = "确认删除「\(items[0].name)」？"
        } else {
            alert.messageText = "确认删除 \(items.count) 个项目？"
        }
        alert.informativeText = "项目将移至废纸篓。"
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = deleteButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
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
        completion()
    }
    
    @discardableResult
    static func moveItem(_ item: FileItem, toNewName newName: String) -> Result<URL, Error> {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteInvalidFileNameError,
                userInfo: [NSLocalizedDescriptionKey: "名称不能为空"]
            ))
        }
        guard trimmed != item.name else {
            return .success(item.url)
        }
        
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            return .success(newURL)
        } catch {
            return .failure(error)
        }
    }
    
    static func showInfo(_ items: [FileItem]) {
        guard !items.isEmpty else { return }
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        
        if items.count == 1, let item = items.first {
            alert.messageText = item.name
            alert.informativeText = buildInfoText(for: item)
        } else {
            alert.messageText = "已选择 \(items.count) 个项目"
            let preview = items.prefix(20).map { item in
                let kind = item.isDirectory ? "文件夹" : "文件"
                return "• \(item.name)（\(kind)，\(item.sizeDisplay)）"
            }.joined(separator: "\n")
            alert.informativeText = items.count > 20 ? preview + "\n…" : preview
        }
        
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
    
    private static func buildInfoText(for item: FileItem) -> String {
        var lines: [String] = []
        
        if item.isDirectory {
            lines.append("种类：文件夹")
        } else if item.url.pathExtension.isEmpty {
            lines.append("种类：文件")
        } else {
            lines.append("种类：\(item.url.pathExtension.uppercased()) 文件")
        }
        
        lines.append("大小：\(item.sizeDisplay)")
        lines.append("位置：\(item.url.deletingLastPathComponent().path)")
        
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
                lines.append("创建时间：\(FileItemFormatters.formatDate(created))")
            }
            lines.append("修改时间：\(item.dateDisplay)")
            lines.append("隐藏：\(item.isHidden ? "是" : "否")")
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: item.url.path),
               let permissions = attributes[.posixPermissions] as? Int {
                lines.append(
                    "权限：\(posixPermissionString(permissions))（\(String(format: "%04o", permissions))）"
                )
            }
            
            var access: [String] = []
            if values.isReadable == true { access.append("可读") }
            if values.isWritable == true { access.append("可写") }
            if values.isExecutable == true { access.append("可执行") }
            if !access.isEmpty {
                lines.append("访问：\(access.joined(separator: "、"))")
            }
            
            if let typeIdentifier = values.typeIdentifier {
                lines.append("类型标识：\(typeIdentifier)")
            }
        }
        
        lines.append("路径：\(item.url.path)")
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
}
