import AppKit

/// 列表/缩略图视图共用的 Services 菜单与标准拖放 destination 转发。
enum FileListDraggingDestinationSupport {
    static func validRequestor(
        servicesRequestor: (any FileListServicesMenuRequestor)?,
        sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?,
        fallback: () -> Any?
    ) -> Any? {
        if let requestor = servicesRequestor?.validRequestor(
            forSendType: sendType,
            returnType: returnType
        ) {
            return requestor
        }
        return fallback()
    }

    static func standardDraggingEntered(_ handler: () -> NSDragOperation) -> NSDragOperation {
        handler()
    }

    static func standardDraggingUpdated(_ handler: () -> NSDragOperation) -> NSDragOperation {
        handler()
    }

    static func standardPrepareForDragOperation(_ handler: () -> NSDragOperation) -> Bool {
        handler() != []
    }

    static func standardPerformDragOperation(_ handler: () -> Bool) -> Bool {
        handler()
    }
}
