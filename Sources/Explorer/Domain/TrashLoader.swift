import Foundation
import FileList

enum TrashLoader {
    /// 稳定逻辑标识，永不本地化。
    static let pathToken = "__TRASH__"
    /// 旧版中文显示名，用于路径栏输入兼容。
    static let legacyChineseDisplayName = "废纸篓"

    /// 仅用于 UI 显示。
    static var displayName: String { L10n.Sidebar.trash }

    static func isTrashInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed == pathToken { return true }
        if trimmed == displayName { return true }
        if trimmed == legacyChineseDisplayName { return true }
        if trimmed == "Trash" { return true }
        return false
    }
    
    static var userTrashPath: String {
        knownTrashDirectoryPaths().first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
    }
    
    static func canonicalTrashPath(_ path: String) -> String {
        var standardized = (path as NSString).standardizingPath
        if standardized.hasPrefix("/private") {
            standardized = String(standardized.dropFirst("/private".count))
        }
        return standardized
    }
    
    /// 用户废纸篓的候选路径（不依赖 fileExists，避免 TCC 导致无法识别废纸篓）。
    static func knownTrashDirectoryPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [String] = [
            FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first?.path,
            (home as NSString).appendingPathComponent(".Trash"),
            "/System/Volumes/Data\(home)/.Trash"
        ].compactMap { $0 }
        
        var paths: [String] = []
        var seen = Set<String>()
        for raw in candidates {
            let path = canonicalTrashPath(raw)
            guard seen.insert(path).inserted else { continue }
            paths.append(path)
        }
        return paths
    }
    
    static func resolvedTrashPaths() -> [String] {
        knownTrashDirectoryPaths().filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
    }
    
    static func isTrashPath(_ path: String) -> Bool {
        let normalized = canonicalTrashPath(path)
        if knownTrashDirectoryPaths().contains(where: { canonicalTrashPath($0) == normalized }) {
            return true
        }
        return trashDirectoryURLs().contains { canonicalTrashPath($0.path) == normalized }
    }
    
    static func trashDirectoryURLs() -> [URL] {
        var urls = knownTrashDirectoryPaths().map { URL(fileURLWithPath: $0, isDirectory: true) }
        var seenPaths = Set(urls.map { canonicalTrashPath($0.path) })
        
        let uid = getuid()
        guard let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) else {
            return urls
        }
        
        for volumeURL in volumeURLs {
            let trashURL = volumeURL.appendingPathComponent(".Trashes/\(uid)", isDirectory: true)
            let path = canonicalTrashPath(trashURL.path)
            guard seenPaths.insert(path).inserted else { continue }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: trashURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                urls.append(trashURL)
            }
        }
        
        return urls
    }
    
    static func loadItems(showHiddenFiles: Bool) async -> [FileItem] {
        var items = loadItemsFromFilesystem(showHiddenFiles: showHiddenFiles)
        if items.isEmpty {
            let finderPaths = await FinderTrashEnumerator.itemPaths()
            items = loadItems(fromPaths: finderPaths, showHiddenFiles: showHiddenFiles)
        }
        return items
    }
    
    private static func loadItemsFromFilesystem(showHiddenFiles: Bool) -> [FileItem] {
        let propertyKeys: Set<URLResourceKey> = [
            .isDirectoryKey, .contentModificationDateKey, .creationDateKey,
            .fileSizeKey, .isHiddenKey, .tagNamesKey
        ]
        var itemsByPath: [String: FileItem] = [:]
        
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]
        
        for trashURL in trashDirectoryURLs() {
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: trashURL,
                    includingPropertiesForKeys: Array(propertyKeys),
                    options: options
                )
                for fileURL in urls {
                    if fileURL.lastPathComponent == ".DS_Store" { continue }
                    guard let item = fileItem(from: fileURL, propertyKeys: propertyKeys) else { continue }
                    let key = canonicalTrashPath(item.id)
                    itemsByPath[key] = item
                }
            } catch {
                print("Error loading trash at \(trashURL.path): \(error)")
            }
        }
        
        return Array(itemsByPath.values)
    }
    
    private static func loadItems(fromPaths paths: [String], showHiddenFiles: Bool) -> [FileItem] {
        let propertyKeys: Set<URLResourceKey> = [
            .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
        ]
        var itemsByPath: [String: FileItem] = [:]
        
        for filePath in paths {
            let fileURL = URL(fileURLWithPath: filePath)
            guard let item = fileItem(from: fileURL, propertyKeys: propertyKeys) else { continue }
            if !showHiddenFiles && item.isHidden { continue }
            let key = canonicalTrashPath(item.id)
            itemsByPath[key] = item
        }
        
        return Array(itemsByPath.values)
    }
    
    static func fileItem(from fileURL: URL, propertyKeys: Set<URLResourceKey>) -> FileItem? {
        let resourceValues = try? fileURL.resourceValues(forKeys: propertyKeys)
        let isDirectory = resourceValues?.isDirectory ?? false
        let modDate = resourceValues?.contentModificationDate ?? Date.distantPast
        let creationDate = resourceValues?.creationDate ?? modDate
        let size = Int64(resourceValues?.fileSize ?? 0)
        let isHidden = resourceValues?.isHidden ?? fileURL.lastPathComponent.hasPrefix(".")
        
        return FileItem(
            id: fileURL.path,
            url: fileURL,
            name: fileURL.lastPathComponent,
            isDirectory: isDirectory,
            modificationDate: modDate,
            creationDate: creationDate,
            size: size,
            isHidden: isHidden,
            fileType: FileItem.fileType(for: fileURL.lastPathComponent, isDirectory: isDirectory),
            sizeDisplay: isDirectory ? "--" : FileItemFormatters.formatSize(size),
            dateDisplay: FileItemFormatters.formatDate(modDate),
            creationDateDisplay: FileItemFormatters.formatDate(creationDate),
            finderComment: FileItem.finderComment(for: fileURL),
            tags: resourceValues?.tagNames ?? []
        )
    }
}

private enum FinderTrashEnumerator {
    static func itemPaths(timeout: TimeInterval = 20) async -> [String] {
        await withCheckedContinuation { continuation in
            final class ResumeGuard: @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false
                private let continuation: CheckedContinuation<[String], Never>
                
                init(continuation: CheckedContinuation<[String], Never>) {
                    self.continuation = continuation
                }
                
                func resumeOnce(_ paths: [String]) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: paths)
                }
            }
            
            let resumeGuard = ResumeGuard(continuation: continuation)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            let script = """
            tell application "Finder"
                set output to ""
                repeat with anItem in trash
                    set output to output & (POSIX path of (anItem as alias)) & linefeed
                end repeat
                return output
            end tell
            """
            process.arguments = ["-e", script]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                let paths = text
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
                    .filter { !$0.isEmpty }
                resumeGuard.resumeOnce(paths)
            }
            
            do {
                try process.run()
            } catch {
                print("Finder trash osascript launch error: \(error)")
                resumeGuard.resumeOnce([])
                return
            }
            
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                process.terminate()
            }
        }
    }
}


struct TrashRestoreRecord: Codable, Equatable {
    let trashedPath: String
    let originalDirectory: String
    let originalName: String
}

/// 记录通过本应用删除的文件原位置，用于「放回原处」。
enum TrashRestoreStore {
    private static func normalized(_ path: String) -> String {
        (path as NSString).standardizingPath
    }
    
    private static func loadRecords() -> [TrashRestoreRecord] {
        guard let data = UserDefaultsStorage.data(forKey: AppPreferences.Data.trashRestoreRecords),
              let records = try? JSONDecoder().decode([TrashRestoreRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func saveRecords(_ records: [TrashRestoreRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaultsStorage.set(data, forKey: AppPreferences.Data.trashRestoreRecords)
    }
    
    static func recordTrash(source: URL, resultingTrashedURL: URL?) {
        let trashedPath = normalized((resultingTrashedURL ?? defaultTrashedURL(for: source)).path)
        let record = TrashRestoreRecord(
            trashedPath: trashedPath,
            originalDirectory: source.deletingLastPathComponent().path,
            originalName: source.lastPathComponent
        )
        
        var records = loadRecords().filter { normalized($0.trashedPath) != trashedPath }
        records.append(record)
        saveRecords(records)
    }
    
    static func record(forTrashedPath path: String) -> TrashRestoreRecord? {
        let target = normalized(path)
        return loadRecords().first { normalized($0.trashedPath) == target }
    }
    
    static func canRestore(trashedPath: String) -> Bool {
        record(forTrashedPath: trashedPath) != nil
    }
    
    static func removeRecord(forTrashedPath path: String) {
        let target = normalized(path)
        let records = loadRecords().filter { normalized($0.trashedPath) != target }
        saveRecords(records)
    }
    
    static func removeAllRecords() {
        UserDefaultsStorage.set(nil, forKey: AppPreferences.Data.trashRestoreRecords)
    }
    
    private static func defaultTrashedURL(for source: URL) -> URL {
        let trashRoot = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        return trashRoot.appendingPathComponent(source.lastPathComponent)
    }
}
