import AppKit

/// FileList 与宿主 App 之间的 Services 菜单 requestor 桥接协议。
@objc public protocol FileListServicesMenuRequestor: NSObjectProtocol {
    @objc func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any?
}

public enum FileListServiceURLs {
    public static func from(rows: [FileListRow], selectedIDs: Set<String>) -> [URL] {
        rows
            .filter { selectedIDs.contains($0.id) && !$0.isParentDirectoryEntry }
            .map { URL(fileURLWithPath: $0.iconPath) }
    }
}
