import AppKit
import Foundation

enum FileListDragSupport {
    static let iconSize: CGFloat = 32
    static let ghostOpacity: CGFloat = 0.72
    
    static func draggedRows(
        for row: FileListRow,
        in rows: [FileListRow],
        selection: Set<String>
    ) -> [FileListRow] {
        guard !row.isParentDirectoryEntry else { return [] }
        var effective = selection
        effective.remove(FileListRow.parentDirectoryID)
        if effective.contains(row.id) {
            return rows.filter { effective.contains($0.id) && !$0.isParentDirectoryEntry }
        }
        return [row]
    }
    
    static func shouldCopyFromCurrentEvent() -> Bool {
        NSApp.currentEvent?.modifierFlags.contains(.option) == true
    }
    
    static func ghostImage(for path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        let size = NSSize(width: iconSize, height: iconSize)
        icon.size = size
        
        let ghost = NSImage(size: size)
        ghost.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
        }
        icon.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .sourceOver,
            fraction: ghostOpacity
        )
        ghost.unlockFocus()
        return ghost
    }
    
    static func iconFrame(anchor: NSRect, index: Int) -> NSRect {
        let offset = CGFloat(index * 6)
        return NSRect(
            x: anchor.midX - iconSize / 2 + offset,
            y: anchor.midY - iconSize / 2 - offset,
            width: iconSize,
            height: iconSize
        )
    }
    
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else { return [] }
        
        var urls: [URL] = []
        var seen = Set<String>()
        for url in items {
            let path = url.standardizedFileURL.path
            if seen.insert(path).inserted {
                urls.append(url.standardizedFileURL)
            }
        }
        return urls
    }
}
