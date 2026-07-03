import AppKit
import AVFoundation
import Foundation
import PDFKit

extension PreviewSession {
    func prepareForLoad() {
        content.imageSaveErrorMessage = nil
        clearLoadedContent()
        content.loadPhase = .loading
        PreviewSessionStateReset.prepareToolbarForLoad(on: self)
    }

    func beginLoadTask(customPreviewRevision: Int) {
        cancelLoad()
        let revision = customPreviewRevision
        prepareForLoad()
        loadTask = Task {
            await loadContent(customPreviewRevision: revision)
        }
    }

    func clearLoadedContent() {
        content.textContent = ""
        content.image = nil
        content.pdfDocument = nil
        content.mediaPlayer?.pause()
        content.mediaPlayer = nil
        content.officeURL = nil
        content.officeRichText = nil
        content.archiveEntries = []
        content.archiveTruncated = false
        content.loadPhase = .idle
        contentLoadedItemID = nil
    }

    func loadTextContentIfNeeded() async {
        let item = browseTarget
        let url = item.url
        let itemID = item.id

        content.loadPhase = .loading

        do {
            let loadedText = try await PreviewContentLoader.loadText(from: url)
            guard !Task.isCancelled else { return }
            guard browseTarget.id == itemID else { return }
            content.textContent = loadedText
            content.loadPhase = .loaded
            syncTextEditStateAfterLoad()
        } catch {
            guard !Task.isCancelled else { return }
            if error is CancellationError { return }
            guard browseTarget.id == itemID else { return }
            content.loadPhase = .failed(error.localizedDescription)
        }
    }

    func saveEditedImage() async {
        await upgradeImageToFullResolutionIfNeeded()
        let item = browseTarget
        guard let sourceImage = content.image else { return }
        let orientedSize = ImagePreviewTransformApplier.orientedPixelSize(
            of: sourceImage,
            rotationQuarterTurns: image.rotationQuarterTurns
        )
        let hasTransformEdits = image.rotationQuarterTurns != 0 || image.flipHorizontal || image.flipVertical
        let hasResizeEdit: Bool = {
            guard let target = image.resizeTargetSize else { return false }
            return Int(target.width.rounded()) != Int(orientedSize.width.rounded())
                || Int(target.height.rounded()) != Int(orientedSize.height.rounded())
        }()
        guard hasTransformEdits || hasResizeEdit else { return }

        let confirmed = await MainActor.run { () -> Bool in
            let alert = NSAlert()
            alert.messageText = "保存编辑结果"
            alert.informativeText = "将覆盖原文件「\(item.name)」。旋转、翻转与尺寸调整会一并写入。GIF 动图保存后可能变为静态图。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "取消")
            return alert.runModal() == .alertFirstButtonReturn
        }
        guard confirmed else { return }

        let rotation = image.rotationQuarterTurns
        let flipH = image.flipHorizontal
        let flipV = image.flipVertical
        let resizeTarget = image.resizeTargetSize
        let url = item.url
        let itemID = item.id

        let saveResult: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
            guard var transformed = ImagePreviewTransformApplier.apply(
                to: sourceImage,
                rotationQuarterTurns: rotation,
                flipHorizontal: flipH,
                flipVertical: flipV
            ) else {
                return .failure(ImagePreviewSaveError.unableToEncode)
            }

            if let resizeTarget {
                let oriented = ImagePreviewTransformApplier.orientedPixelSize(
                    of: sourceImage,
                    rotationQuarterTurns: rotation
                )
                let targetWidth = Int(resizeTarget.width.rounded())
                let targetHeight = Int(resizeTarget.height.rounded())
                let orientedWidth = Int(oriented.width.rounded())
                let orientedHeight = Int(oriented.height.rounded())
                if targetWidth != orientedWidth || targetHeight != orientedHeight {
                    guard let resized = ImagePreviewTransformApplier.resize(
                        transformed,
                        to: CGSize(width: targetWidth, height: targetHeight)
                    ) else {
                        return .failure(ImagePreviewSaveError.unableToEncode)
                    }
                    transformed = resized
                }
            }

            do {
                try ImagePreviewTransformApplier.write(transformed, to: url)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        guard browseTarget.id == itemID else { return }
        switch saveResult {
        case .success:
            image.rotationQuarterTurns = 0
            image.flipHorizontal = false
            image.flipVertical = false
            image.resizeTargetSize = nil
            image.zoomScale = 1.0
            image.zoomAction = .fit
            content.imageSaveErrorMessage = nil
            image.editUndoClearNonce += 1
            beginLoadTask(customPreviewRevision: Int(CustomPreviewRuleStore.shared.revision))
        case .failure(let error):
            content.imageSaveErrorMessage = error.localizedDescription
        }
    }

    func scheduleDeferredTextLoad(from url: URL, itemID: String) {
        Task.detached(priority: .utility) { [url, itemID] () async in
            let loadedText = try? await PreviewContentLoader.loadText(from: url)
            await MainActor.run {
                guard self.browseTarget.id == itemID else { return }
                if let loadedText {
                    self.content.textContent = loadedText
                    self.syncTextEditStateAfterLoad()
                }
            }
        }
    }
}
