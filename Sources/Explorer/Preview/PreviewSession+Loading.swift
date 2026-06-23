import AppKit
import AVFoundation
import Foundation
import PDFKit

extension PreviewSession {
    func prepareForLoad() {
        imageSaveErrorMessage = nil
        clearLoadedContent()
        loadPhase = .loading
        imageZoomScale = 1.0
        imageZoomAction = nil
        imageEffectiveZoomPercent = 0
        imageRotationQuarterTurns = 0
        imageFlipHorizontal = false
        imageFlipVertical = false
        imagePreviewAction = nil
        imageEyedropperActive = false
        imagePickedWebColor = nil
        imageResizeTargetSize = nil
        textPreviewAction = nil
        mediaControlAction = nil
        mediaIsPlaying = false
        mediaIsMuted = false
        officeReloadToken = 0
        officeZoomScale = 1.0
        officePanMode = false
        archiveCopyAction = nil
        pdfCurrentPage = 0
        pdfPageCount = 0
        pdfScalePercent = 0
        pdfNavigateAction = nil
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
        textContent = ""
        image = nil
        pdfDocument = nil
        mediaPlayer?.pause()
        mediaPlayer = nil
        officeURL = nil
        officeRichText = nil
        archiveEntries = []
        archiveTruncated = false
    }

    func loadTextContentIfNeeded() async {
        let item = browseTarget
        let url = item.url
        let itemID = item.id

        loadPhase = .loading

        do {
            let content = try await Task.detached(priority: .userInitiated) {
                try TextFilePreviewReader.readPreview(from: url)
            }.value
            guard !Task.isCancelled else { return }
            guard browseTarget.id == itemID else { return }
            textContent = content
            loadPhase = .loaded
        } catch {
            guard !Task.isCancelled else { return }
            if error is CancellationError { return }
            guard browseTarget.id == itemID else { return }
            loadPhase = .failed(error.localizedDescription)
        }
    }

    func saveEditedImage() async {
        let item = browseTarget
        guard let sourceImage = image else { return }
        let orientedSize = ImagePreviewTransformApplier.orientedPixelSize(
            of: sourceImage,
            rotationQuarterTurns: imageRotationQuarterTurns
        )
        let hasTransformEdits = imageRotationQuarterTurns != 0 || imageFlipHorizontal || imageFlipVertical
        let hasResizeEdit: Bool = {
            guard let target = imageResizeTargetSize else { return false }
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

        let rotation = imageRotationQuarterTurns
        let flipH = imageFlipHorizontal
        let flipV = imageFlipVertical
        let resizeTarget = imageResizeTargetSize
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
            imageRotationQuarterTurns = 0
            imageFlipHorizontal = false
            imageFlipVertical = false
            imageResizeTargetSize = nil
            imageZoomScale = 1.0
            imageZoomAction = .fit
            imageSaveErrorMessage = nil
            imageEditUndoClearNonce += 1
            beginLoadTask(customPreviewRevision: Int(CustomPreviewRuleStore.shared.revision))
        case .failure(let error):
            imageSaveErrorMessage = error.localizedDescription
        }
    }

    private func loadContent(customPreviewRevision: Int) async {
        let item = browseTarget

        let url = item.url
        let ext = url.pathExtension.lowercased()
        let itemID = item.id
        let customPreviewStore = CustomPreviewRuleStore.shared
        _ = customPreviewRevision

        @MainActor
        func finish(
            imageData: Data? = nil,
            pdfData: Data? = nil,
            mediaURL: URL? = nil,
            office loadedOfficeURL: URL? = nil,
            officeRichText loadedOfficeRichText: NSAttributedString? = nil,
            archive loadedArchiveEntries: [ArchiveEntryPreview]? = nil,
            archiveTruncated loadedArchiveTruncated: Bool = false,
            text content: String? = nil,
            error: String? = nil
        ) {
            guard !Task.isCancelled, browseTarget.id == itemID else { return }
            if let imageData {
                guard let decodedImage = NSImage(data: imageData) else {
                    image = nil
                    imageSourcePixelSize = .zero
                    loadPhase = .failed("Unable to decode image format")
                    return
                }
                image = decodedImage
                imageSourcePixelSize = ImagePreviewTransformApplier.pixelSize(of: decodedImage)
            } else {
                image = nil
                imageSourcePixelSize = .zero
            }
            if let pdfData {
                guard let decodedPDF = PDFDocument(data: pdfData) else {
                    pdfDocument = nil
                    loadPhase = .failed("Unable to load PDF document")
                    return
                }
                pdfDocument = decodedPDF
            } else {
                pdfDocument = nil
            }
            if let mediaURL {
                mediaIsPlaying = false
                mediaIsMuted = false
                mediaControlAction = nil
                let player = AVPlayer(url: mediaURL)
                player.actionAtItemEnd = .pause
                mediaPlayer = player
            } else {
                mediaPlayer = nil
            }
            officeURL = loadedOfficeRichText == nil ? loadedOfficeURL : nil
            officeRichText = loadedOfficeRichText
            archiveEntries = loadedArchiveEntries ?? []
            archiveTruncated = loadedArchiveTruncated
            if let content { textContent = content }
            if let error {
                loadPhase = .failed(error)
            } else {
                loadPhase = .loaded
            }
        }

        if let overrideRule = customPreviewStore.overridingRule(for: ext) {
            await loadCustomPreview(mode: overrideRule.mode, url: url, ext: ext, itemID: itemID, finish: finish)
            return
        }

        if BuiltinPreviewExtensions.image.contains(ext) {
            if let prefetched = browseContentPrefetcher.consume(for: itemID) {
                guard !Task.isCancelled else { return }
                finish(imageData: prefetched)
                scheduleBrowseContentPrefetch()
                return
            }
            let imageData = try? await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url, options: [.mappedIfSafe])
            }.value
            guard !Task.isCancelled else { return }
            if let imageData {
                finish(imageData: imageData)
            } else {
                finish(error: "Unable to decode image format")
            }
            scheduleBrowseContentPrefetch()
            return
        }

        if BuiltinPreviewExtensions.media.contains(ext) {
            guard !Task.isCancelled else { return }
            finish(mediaURL: url)
            return
        }

        if ext == "docx" {
            guard !Task.isCancelled else { return }
            let richText = try? await Task.detached(priority: .userInitiated) {
                try OfficeDocumentPreviewLoader.loadDOCX(from: url)
            }.value
            guard !Task.isCancelled else { return }
            if let richText {
                finish(officeRichText: richText)
            } else {
                finish(office: url)
            }
            return
        }

        if BuiltinPreviewExtensions.office.contains(ext) {
            guard !Task.isCancelled else { return }
            finish(office: url)
            return
        }

        if BuiltinPreviewExtensions.pdf.contains(ext) {
            if let prefetched = browseContentPrefetcher.consume(for: itemID) {
                guard !Task.isCancelled else { return }
                finish(pdfData: prefetched)
                scheduleBrowseContentPrefetch()
                return
            }
            let pdfData = try? await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url, options: [.mappedIfSafe])
            }.value
            guard !Task.isCancelled else { return }
            if let pdfData {
                finish(pdfData: pdfData)
            } else {
                finish(error: "Unable to load PDF document")
            }
            scheduleBrowseContentPrefetch()
            return
        }

        let lowerName = url.lastPathComponent.lowercased()
        let maxEntries = 1_000
        let timeoutSeconds = 8

        func shellEscape(_ s: String) -> String {
            "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }

        func runShellCapture(_ command: String) async throws -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()

            let start = Date()
            while process.isRunning {
                if Task.isCancelled {
                    process.terminate()
                    throw CancellationError()
                }
                if Date().timeIntervalSince(start) > Double(timeoutSeconds) {
                    process.terminate()
                    throw NSError(domain: "ArchivePreview", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "目录读取超时",
                    ])
                }
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }

        if lowerName.hasSuffix(".zip") {
            do {
                let escaped = shellEscape(url.path)
                let command =
                    "/usr/bin/unzip -l " + escaped +
                    " | /usr/bin/head -n " + "\(maxEntries * 2 + 60)"
                let output = try await runShellCapture(command)

                var entries: [ArchiveEntryPreview] = []
                for rawLine in output.split(whereSeparator: \.isNewline) {
                    if entries.count >= maxEntries { break }
                    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    let tokens = line.split(whereSeparator: { $0.isWhitespace })
                    guard tokens.count >= 4 else { continue }
                    guard let size = Int(tokens[0]) else { continue }
                    let nameTokens = tokens.dropFirst(3)
                    let path = nameTokens.joined(separator: " ")
                    guard !path.isEmpty else { continue }
                    let isDir = path.hasSuffix("/")
                    entries.append(.init(path: path, isDirectory: isDir, size: Int64(size)))
                }
                if entries.isEmpty {
                    finish(error: "无法读取 ZIP 目录")
                } else {
                    finish(archive: entries, archiveTruncated: entries.count >= maxEntries)
                }
            } catch {
                if error is CancellationError { return }
                finish(error: error.localizedDescription)
            }
            return
        } else if lowerName.hasSuffix(".tar") || lowerName.hasSuffix(".tar.gz") || lowerName.hasSuffix(".tgz") {
            do {
                let escaped = shellEscape(url.path)
                let command =
                    "/usr/bin/tar -tf " + escaped +
                    " 2>&1 | /usr/bin/head -n " + "\(maxEntries + 80)"
                let output = try await runShellCapture(command)

                var entries: [ArchiveEntryPreview] = []
                for rawLine in output.split(whereSeparator: \.isNewline) {
                    if entries.count >= maxEntries { break }
                    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if line.isEmpty { continue }
                    if line.hasPrefix("tar:") { continue }
                    entries.append(.init(path: line, isDirectory: line.hasSuffix("/"), size: nil))
                }

                if entries.isEmpty {
                    finish(error: "无法读取归档目录")
                } else {
                    finish(archive: entries, archiveTruncated: entries.count >= maxEntries)
                }
            } catch {
                if error is CancellationError { return }
                finish(error: error.localizedDescription)
            }
            return
        }

        let textExtensions = BuiltinPreviewExtensions.text

        if textExtensions.contains(ext) {
            if isHtmlFile(item), htmlMode == .preview {
                finish()
                Task.detached(priority: .utility) { [url, itemID] in
                    let content = try? TextFilePreviewReader.readPreview(from: url)
                    await MainActor.run {
                        guard self.browseTarget.id == itemID else { return }
                        if let content {
                            self.textContent = content
                        }
                    }
                }
                return
            }

            do {
                let content = try await Task.detached(priority: .userInitiated) {
                    try TextFilePreviewReader.readPreview(from: url)
                }.value
                guard !Task.isCancelled else { return }
                finish(text: content)
            } catch {
                guard !Task.isCancelled else { return }
                if error is CancellationError { return }
                finish(error: error.localizedDescription)
            }
            return
        }

        if let customMode = customPreviewStore.activeMode(for: ext) {
            await loadCustomPreview(mode: customMode, url: url, ext: ext, itemID: itemID, finish: finish)
            return
        }

        finish()
    }

    private func loadCustomPreview(
        mode: CustomPreviewMode,
        url: URL,
        ext: String,
        itemID: String,
        finish: @MainActor (
            _ imageData: Data?,
            _ pdfData: Data?,
            _ mediaURL: URL?,
            _ office: URL?,
            _ officeRichText: NSAttributedString?,
            _ archive: [ArchiveEntryPreview]?,
            _ archiveTruncated: Bool,
            _ text: String?,
            _ error: String?
        ) -> Void
    ) async {
        switch mode {
        case .quickLook:
            guard !Task.isCancelled else { return }
            finish(nil, nil, nil, url, nil, nil, false, nil, nil)
        case .media:
            guard !Task.isCancelled else { return }
            finish(nil, nil, url, nil, nil, nil, false, nil, nil)
        case .image:
            let imageData = try? await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url, options: [.mappedIfSafe])
            }.value
            guard !Task.isCancelled else { return }
            if let imageData {
                finish(imageData, nil, nil, nil, nil, nil, false, nil, nil)
            } else {
                finish(nil, nil, nil, nil, nil, nil, false, nil, "Unable to decode image format")
            }
        case .pdf:
            let pdfData = try? await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url, options: [.mappedIfSafe])
            }.value
            guard !Task.isCancelled else { return }
            if let pdfData {
                finish(nil, pdfData, nil, nil, nil, nil, false, nil, nil)
            } else {
                finish(nil, nil, nil, nil, nil, nil, false, nil, "Unable to load PDF document")
            }
        case .html where htmlMode == .preview:
            finish(nil, nil, nil, nil, nil, nil, false, nil, nil)
            Task.detached(priority: .utility) { [url, itemID] in
                let content = try? TextFilePreviewReader.readPreview(from: url)
                await MainActor.run {
                    guard self.browseTarget.id == itemID else { return }
                    if let content {
                        self.textContent = content
                    }
                }
            }
        case .text, .markdown, .html:
            do {
                let content = try await Task.detached(priority: .userInitiated) {
                    try TextFilePreviewReader.readPreview(from: url)
                }.value
                guard !Task.isCancelled else { return }
                finish(nil, nil, nil, nil, nil, nil, false, content, nil)
            } catch {
                guard !Task.isCancelled else { return }
                if error is CancellationError { return }
                finish(nil, nil, nil, nil, nil, nil, false, nil, error.localizedDescription)
            }
        }
    }

    private func isHtmlFile(_ item: FileItem) -> Bool {
        PreviewTypeClassifier.isHtmlFile(item.url.pathExtension)
    }
}
