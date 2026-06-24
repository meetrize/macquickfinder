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
            guard let decodedImage = NSImage(data: imageData) else {
                content.image = nil
                image.sourcePixelSize = .zero
                content.loadPhase = .failed("Unable to decode image format")
                return true
            }
            content.image = decodedImage
            image.sourcePixelSize = ImagePreviewTransformApplier.pixelSize(of: decodedImage)
        } else {
            content.image = nil
            image.sourcePixelSize = .zero
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

        if let textContent = payload.textContent {
            content.textContent = textContent
        }

        if let error = payload.error {
            content.loadPhase = .failed(error)
        } else {
            content.loadPhase = .loaded
        }
        return true
    }
}
