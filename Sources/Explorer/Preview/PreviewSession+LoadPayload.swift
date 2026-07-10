import AppKit
import AVFoundation
import Foundation
import PDFKit

extension PreviewSession {
    /// 将加载结果写入 session；若 item 已切换或任务已取消则返回 false。
    @discardableResult
    func applyLoadPayload(_ payload: PreviewLoadPayload, expectedItemID: String) -> Bool {
        guard !Task.isCancelled, browseTarget.id == expectedItemID else { return false }

        if let imageData = payload.imageData {
            let url = browseTarget.url
            let maxPixelSize = payload.imageMaxPixelSize ?? imagePreviewDisplayMaxPixelSize(for: url)
            guard applyImagePreview(
                data: imageData,
                url: url,
                maxPixelSize: maxPixelSize,
                expectedItemID: expectedItemID
            ) else {
                return false
            }
        } else {
            content.image = nil
            image.sourcePixelSize = .zero
            image.decodedMaxPixelSize = 0
        }

        if let pdfData = payload.pdfData {
            guard let decodedPDF = PDFDocument(data: pdfData) else {
                content.pdfDocument = nil
                content.loadPhase = .failed("Unable to load PDF document")
                return true
            }
            content.pdfDocument = decodedPDF
        } else {
            content.pdfDocument = nil
        }

        if let mediaURL = payload.mediaURL {
            media.isPlaying = false
            media.isMuted = false
            media.controlAction = nil
            let player = AVPlayer(url: mediaURL)
            player.actionAtItemEnd = .pause
            content.mediaPlayer = player
        } else {
            content.mediaPlayer = nil
        }

        content.officeURL = payload.officeRichText == nil ? payload.officeURL : nil
        content.officeRichText = payload.officeRichText
        content.archiveEntries = payload.archiveEntries ?? []
        content.archiveTruncated = payload.archiveTruncated

        if let epubPackage = payload.epubPackage {
            if content.epubPackage?.extractedRoot != epubPackage.extractedRoot {
                EpubPreviewLoader.cleanup(extractedRoot: content.epubPackage?.extractedRoot)
            }
            content.epubPackage = epubPackage
        } else {
            EpubPreviewLoader.cleanup(extractedRoot: content.epubPackage?.extractedRoot)
            content.epubPackage = nil
        }

        content.emlContent = payload.emlContent

        if let fontContent = payload.fontContent {
            if content.fontContent?.sourcePath != fontContent.sourcePath {
                if let previous = content.fontContent {
                    FontPreviewLoader.unregisterFontForPreview(at: previous.sourceURL)
                }
            }
            content.fontContent = fontContent
        } else {
            if let previous = content.fontContent {
                FontPreviewLoader.unregisterFontForPreview(at: previous.sourceURL)
            }
            content.fontContent = nil
        }

        if let model3DContent = payload.model3DContent {
            content.model3DContent = model3DContent
        } else {
            content.model3DContent = nil
        }

        if let textContent = payload.textContent {
            content.textContent = textContent
            syncTextEditStateAfterLoad()
        }

        if let error = payload.error {
            content.loadPhase = .failed(error)
        } else if case .failed = content.loadPhase {
            // 保留图片解码等步骤已写入的失败状态
        } else {
            content.loadPhase = .loaded
            contentLoadedItemID = expectedItemID
        }
        return true
    }
}
