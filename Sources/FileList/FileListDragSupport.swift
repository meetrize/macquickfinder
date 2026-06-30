import AppKit
import Foundation

enum FileListDragSupport {
    static let iconSize: CGFloat = 32
    static let ghostOpacity: CGFloat = 1.0
    static let labelSpacing: CGFloat = 8
    static let labelPadding = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 8)
    static let maxLabelWidth: CGFloat = 240
    
    struct DragGhost {
        let image: NSImage
        let size: NSSize
    }
    
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
    
    static func shouldCopy(from draggingInfo: NSDraggingInfo) -> Bool {
        if shouldCopyFromCurrentEvent() { return true }
        return draggingInfo.draggingSourceOperationMask.contains(.copy)
    }
    
    static func makeDragGhost(for path: String, name: String, showLabel: Bool) -> DragGhost {
        let icon = NSWorkspace.shared.icon(forFile: path)
        let iconDrawSize = NSSize(width: iconSize, height: iconSize)
        icon.size = iconDrawSize
        
        guard showLabel else {
            let ghost = NSImage(size: iconDrawSize)
            ghost.lockFocus()
            defer { ghost.unlockFocus() }
            if let context = NSGraphicsContext.current {
                context.imageInterpolation = .high
            }
            icon.draw(
                in: NSRect(origin: .zero, size: iconDrawSize),
                from: NSRect(origin: .zero, size: icon.size),
                operation: .sourceOver,
                fraction: ghostOpacity
            )
            return DragGhost(image: ghost, size: iconDrawSize)
        }
        
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        let labelText = truncatedLabel(name, font: font, maxWidth: maxLabelWidth)
        let labelSize = (labelText as NSString).size(withAttributes: labelAttributes)
        
        let contentWidth = iconSize + labelSpacing + labelSize.width
        let contentHeight = max(iconSize, labelSize.height)
        let imageSize = NSSize(
            width: contentWidth + labelPadding.left + labelPadding.right,
            height: contentHeight + labelPadding.top + labelPadding.bottom
        )
        
        let ghost = NSImage(size: imageSize)
        ghost.lockFocus()
        defer { ghost.unlockFocus() }
        
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
        }
        
        let backgroundRect = NSRect(origin: .zero, size: imageSize).insetBy(dx: 0.5, dy: 0.5)
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 6, yRadius: 6)
        NSColor.windowBackgroundColor.withAlphaComponent(0.94).setFill()
        backgroundPath.fill()
        NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
        backgroundPath.lineWidth = 1
        backgroundPath.stroke()
        
        let iconY = labelPadding.bottom + (contentHeight - iconSize) / 2
        icon.draw(
            in: NSRect(x: labelPadding.left, y: iconY, width: iconSize, height: iconSize),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .sourceOver,
            fraction: ghostOpacity
        )
        
        let textX = labelPadding.left + iconSize + labelSpacing
        let textY = labelPadding.bottom + (contentHeight - labelSize.height) / 2
        (labelText as NSString).draw(
            at: NSPoint(x: textX, y: textY),
            withAttributes: labelAttributes
        )
        
        return DragGhost(image: ghost, size: imageSize)
    }
    
    static func iconCenterX(showLabel: Bool) -> CGFloat {
        showLabel ? labelPadding.left + iconSize / 2 : iconSize / 2
    }

    static func draggingFrame(
        at point: NSPoint,
        ghostSize: NSSize,
        index: Int,
        showLabel: Bool
    ) -> NSRect {
        let stackOffset = CGFloat(index * 6)
        let anchorX = iconCenterX(showLabel: showLabel)
        return NSRect(
            x: point.x - anchorX + stackOffset,
            y: point.y - ghostSize.height / 2 - stackOffset,
            width: ghostSize.width,
            height: ghostSize.height
        )
    }
    
    private static func truncatedLabel(_ name: String, font: NSFont, maxWidth: CGFloat) -> String {
        let text = name as NSString
        if text.size(withAttributes: [.font: font]).width <= maxWidth {
            return name
        }
        
        let ellipsis = "…"
        var truncated = name
        while !truncated.isEmpty {
            let candidate = truncated + ellipsis
            if (candidate as NSString).size(withAttributes: [.font: font]).width <= maxWidth {
                return candidate
            }
            truncated.removeLast()
        }
        return ellipsis
    }
    
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
        ]) as? [URL], !items.isEmpty {
            return deduplicatedFileURLs(items)
        }
        
        if let items = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !items.isEmpty {
            let fileURLs = items.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                return deduplicatedFileURLs(fileURLs)
            }
        }
        
        for type in [
            NSPasteboard.PasteboardType.fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
        ] {
            if let string = pasteboard.string(forType: type)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !string.isEmpty {
                let url = URL(string: string) ?? URL(fileURLWithPath: string)
                if url.isFileURL {
                    return deduplicatedFileURLs([url])
                }
            }
        }
        
        if let paths = pasteboard.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String], !paths.isEmpty {
            return deduplicatedFileURLs(paths.map { URL(fileURLWithPath: $0) })
        }
        
        return []
    }
    
    private static func deduplicatedFileURLs(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()
        for url in urls {
            let path = url.standardizedFileURL.path
            if seen.insert(path).inserted {
                result.append(url.standardizedFileURL)
            }
        }
        return result
    }
}
