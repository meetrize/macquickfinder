import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension.lowercased()
        if BuiltinPreviewExtensions.quickLookImage.contains(ext) {
            return prependRunnableScriptRunButton(to: previewQuickLookImageToolbarItems(for: item), for: item)
        }
        if PreviewTypeClassifier.isImageFile(ext) {
            return prependRunnableScriptRunButton(to: previewImageToolbarItems(for: item), for: item)
        }
        if PreviewTypeClassifier.isPDFFile(ext) {
            return prependRunnableScriptRunButton(to: previewPDFToolbarItems(), for: item)
        }
        if PreviewTypeClassifier.isSpreadsheetFile(ext) {
            return prependRunnableScriptRunButton(to: previewSpreadsheetToolbarItems(for: item), for: item)
        }
        if PreviewTypeClassifier.isTextFile(ext) {
            return prependRunnableScriptRunButton(to: previewTextToolbarItems(for: item), for: item)
        }
        if PreviewTypeClassifier.isMediaFile(ext) {
            return prependRunnableScriptRunButton(to: previewMediaToolbarItems(), for: item)
        }
        if PreviewTypeClassifier.isWordDocumentFile(ext) {
            return prependRunnableScriptRunButton(to: previewWordDocumentToolbarItems(for: item), for: item)
        }
        if PreviewTypeClassifier.isOfficeFile(ext) {
            return prependRunnableScriptRunButton(to: previewOfficeToolbarItems(for: item), for: item)
        }
        if PreviewTypeClassifier.isArchivePreviewFile(item) {
            return prependRunnableScriptRunButton(to: previewArchiveToolbarItems(), for: item)
        }
        if PreviewTypeClassifier.isEpubFile(ext), content.epubPackage != nil {
            return prependRunnableScriptRunButton(to: previewEpubToolbarItems(), for: item)
        }
        if PreviewTypeClassifier.isModel3DFile(ext), content.model3DContent != nil {
            return prependRunnableScriptRunButton(to: previewModel3DToolbarItems(for: item), for: item)
        }
        return prependRunnableScriptRunButton(to: [], for: item)
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
