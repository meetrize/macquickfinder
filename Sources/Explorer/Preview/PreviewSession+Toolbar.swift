import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension.lowercased()
        if BuiltinPreviewExtensions.quickLookImage.contains(ext) {
            return previewQuickLookImageToolbarItems(for: item)
        }
        if PreviewTypeClassifier.isImageFile(ext) {
            return previewImageToolbarItems(for: item)
        }
        if PreviewTypeClassifier.isPDFFile(ext) {
            return previewPDFToolbarItems()
        }
        if PreviewTypeClassifier.isTextFile(ext) {
            return previewTextToolbarItems(for: item)
        }
        if PreviewTypeClassifier.isMediaFile(ext) {
            return previewMediaToolbarItems()
        }
        if PreviewTypeClassifier.isSpreadsheetFile(ext) {
            return previewSpreadsheetToolbarItems(for: item)
        }
        if PreviewTypeClassifier.isWordDocumentFile(ext) {
            return previewWordDocumentToolbarItems(for: item)
        }
        if PreviewTypeClassifier.isOfficeFile(ext) {
            return previewOfficeToolbarItems(for: item)
        }
        if PreviewTypeClassifier.isArchivePreviewFile(item) {
            return previewArchiveToolbarItems()
        }
        return []
    }

    func previewToolbarIconItem(
        id: String,
        title: String,
        systemImage: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> PreviewToolbarOverflowModel {
        PreviewToolbarOverflowModel(
            id: id,
            menuTitle: title,
            menuSystemImage: systemImage,
            isDisabled: isDisabled,
            estimatedWidth: 20,
            menuAction: action,
            content: AnyView(
                PreviewFocuslessIconButton(
                    systemImageName: systemImage,
                    accessibilityLabel: title,
                    action: action
                )
                .disabled(isDisabled)
                .instantHoverTooltip(title)
            )
        )
    }

    func copyImageToPasteboard(_ item: FileItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = NSImage(contentsOf: item.url) {
            pasteboard.writeObjects([image])
        } else {
            pasteboard.writeObjects([item.url as NSURL])
        }
    }

    func colorFromWebHex(_ hex: String) -> Color {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }
        guard text.count == 6, let value = UInt32(text, radix: 16) else {
            return .clear
        }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }
}
