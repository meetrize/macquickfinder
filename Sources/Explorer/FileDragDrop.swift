import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum FileDragDrop {
    static func shouldCopyFromCurrentEvent() -> Bool {
        NSApp.currentEvent?.modifierFlags.contains(.option) == true
    }
    
    static func shouldCopyFromDropInfo(_ info: DropInfo) -> Bool {
        _ = info
        return shouldCopyFromCurrentEvent()
    }
    
    static func shouldCopyFromDraggingInfo(_ info: NSDraggingInfo) -> Bool {
        _ = info
        return shouldCopyFromCurrentEvent()
    }
    
    static func dragOperation(for info: NSDraggingInfo) -> NSDragOperation {
        shouldCopyFromDraggingInfo(info) ? .copy : .move
    }
    
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        
        func append(_ url: URL) {
            let standardized = url.standardizedFileURL
            if seen.insert(standardized.path).inserted {
                urls.append(standardized)
            }
        }
        
        if let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            objects.forEach { append($0) }
        }
        
        if let paths = pasteboard.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String] {
            paths.forEach { append(URL(fileURLWithPath: $0)) }
        }
        
        if let paths = pasteboard.propertyList(forType: .fileURL) as? [String] {
            paths.forEach { append(URL(fileURLWithPath: $0)) }
        }
        
        return urls
    }
    
    @MainActor
    static func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                let path = url.standardizedFileURL.path
                if seen.insert(path).inserted {
                    urls.append(url)
                }
            }
        }
        return urls
    }
    
    @MainActor
    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { item, _ in
                continuation.resume(returning: item?.standardizedFileURL)
            }
        }
    }
}



