import AppKit
import SwiftUI

extension PreviewSession {
    func previewToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension
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
        if PreviewTypeClassifier.isOfficeFile(ext) {
            return previewOfficeToolbarItems(for: item)
        }
        if BuiltinPreviewExtensions.matchesArchive(fileName: item.url.lastPathComponent) {
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
                Button(action: action) {
                    Image(systemName: systemImage)
                }
                .buttonStyle(.borderless)
                .disabled(isDisabled)
                .help(title)
            )
        )
    }

    func previewImageToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        var items: [PreviewToolbarOverflowModel] = [
            PreviewToolbarOverflowModel(
                id: "image-zoom",
                menuTitle: "缩放",
                menuSystemImage: "plus.magnifyingglass",
                isDisabled: false,
                estimatedWidth: 120,
                menuAction: {},
                content: AnyView(PreviewImageZoomToolbarControls(session: self))
            ),
            previewToolbarIconItem(
                id: "image-rotate-left",
                title: "逆时针旋转",
                systemImage: "rotate.left",
                action: { [self] in
                    performImageEdit {
                        imageRotationQuarterTurns = (imageRotationQuarterTurns + 3) % 4
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-rotate-right",
                title: "顺时针旋转",
                systemImage: "rotate.right",
                action: { [self] in
                    performImageEdit {
                        imageRotationQuarterTurns = (imageRotationQuarterTurns + 1) % 4
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-flip-horizontal",
                title: "水平翻转",
                systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                action: { [self] in
                    performImageEdit {
                        imageFlipHorizontal.toggle()
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-flip-vertical",
                title: "垂直翻转",
                systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                action: { [self] in
                    performImageEdit {
                        imageFlipVertical.toggle()
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-undo",
                title: "撤销上一步",
                systemImage: "arrow.uturn.backward",
                isDisabled: imageEditUndoStack.isEmpty,
                action: { [self] in undoLastImageEdit() }
            ),
            previewToolbarIconItem(
                id: "image-reset",
                title: "重置视图",
                systemImage: "arrow.counterclockwise",
                action: { [self] in resetImageViewTransform() }
            ),
            previewToolbarIconItem(
                id: "image-resize",
                title: "调整尺寸",
                systemImage: "arrow.up.backward.and.arrow.down.forward",
                isDisabled: imageSourcePixelSize.width <= 0 || imageSourcePixelSize.height <= 0,
                action: { [self] in showImageResizeSheet = true }
            ),
            previewToolbarIconItem(
                id: "image-save",
                title: "保存编辑结果",
                systemImage: "square.and.arrow.down",
                isDisabled: !hasImageEdits,
                action: { [self] in imagePreviewAction = .save }
            ),
            PreviewToolbarOverflowModel(
                id: "image-eyedropper",
                menuTitle: "取色棒",
                menuSystemImage: "eyedropper",
                isDisabled: false,
                estimatedWidth: 20,
                menuAction: { [self] in imageEyedropperActive.toggle() },
                content: AnyView(PreviewImageEyedropperToolbarButton(session: self))
            ),
            previewToolbarIconItem(
                id: "image-copy",
                title: "复制图片",
                systemImage: "doc.on.doc",
                action: { [self] in copyImageToPasteboard(item) }
            ),
            previewToolbarIconItem(
                id: "image-open",
                title: "用默认应用打开",
                systemImage: "arrow.up.forward.app",
                action: { NSWorkspace.shared.open(item.url) }
            ),
        ]

        if let hex = imagePickedWebColor {
            items.insert(
                PreviewToolbarOverflowModel(
                    id: "image-color",
                    menuTitle: "颜色 \(hex)",
                    menuSystemImage: "eyedropper.half.filled",
                    isDisabled: false,
                    estimatedWidth: 72,
                    menuAction: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hex, forType: .string)
                    },
                    content: AnyView(PreviewImageColorSwatch(hex: hex, session: self))
                ),
                at: items.count - 2
            )
        }

        return items
    }

    func previewPDFToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "pdf-prev",
                title: "上一页",
                systemImage: "chevron.left",
                isDisabled: pdfCurrentPage <= 1,
                action: { [self] in pdfNavigateAction = .previous }
            ),
            previewToolbarIconItem(
                id: "pdf-zoom-out",
                title: "缩小",
                systemImage: "minus.magnifyingglass",
                isDisabled: pdfScalePercent > 0 && pdfScalePercent <= 25,
                action: { [self] in pdfNavigateAction = .zoomOut }
            ),
            PreviewToolbarOverflowModel(
                id: "pdf-page",
                menuTitle: "页码",
                menuSystemImage: "number",
                isDisabled: false,
                estimatedWidth: 82,
                menuAction: {},
                content: AnyView(PreviewPDFPageInputField(session: self))
            ),
            PreviewToolbarOverflowModel(
                id: "pdf-scale",
                menuTitle: "缩放比例",
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text(pdfScalePercent > 0 ? "\(pdfScalePercent)%" : "--")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                )
            ),
            previewToolbarIconItem(
                id: "pdf-zoom-in",
                title: "放大",
                systemImage: "plus.magnifyingglass",
                isDisabled: pdfScalePercent >= 500,
                action: { [self] in pdfNavigateAction = .zoomIn }
            ),
            previewToolbarIconItem(
                id: "pdf-fit-width",
                title: "适配宽度",
                systemImage: "arrow.left.and.right.square",
                action: { [self] in pdfNavigateAction = .fitWidth }
            ),
            previewToolbarIconItem(
                id: "pdf-fit-page",
                title: "整页适配",
                systemImage: "arrow.up.left.and.arrow.down.right",
                action: { [self] in pdfNavigateAction = .fitPage }
            ),
            previewToolbarIconItem(
                id: "pdf-next",
                title: "下一页",
                systemImage: "chevron.right",
                isDisabled: pdfPageCount == 0 || pdfCurrentPage >= pdfPageCount,
                action: { [self] in pdfNavigateAction = .next }
            ),
        ]
    }

    func previewTextToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension
        var items: [PreviewToolbarOverflowModel] = [
            previewToolbarIconItem(
                id: "text-wrap",
                title: textWrapEnabled ? "关闭自动换行" : "开启自动换行",
                systemImage: textWrapEnabled ? "text.justify.left" : "arrow.left.and.right.text.vertical",
                action: { [self] in textWrapEnabled.toggle() }
            ),
        ]

        if PreviewTypeClassifier.isMarkdownFile(ext) {
            items.append(
                previewToolbarIconItem(
                    id: "md-preview",
                    title: "预览模式",
                    systemImage: markdownMode == .preview ? "eye.fill" : "eye",
                    action: { [self] in markdownMode = .preview }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "md-source",
                    title: "源码模式",
                    systemImage: markdownMode == .source ? "doc.plaintext.fill" : "doc.plaintext",
                    action: { [self] in markdownMode = .source }
                )
            )

            if markdownMode == .preview {
                items.append(
                    previewToolbarIconItem(
                        id: "md-zoom-in",
                        title: "放大（整体）",
                        systemImage: "plus.magnifyingglass",
                        action: { [self] in markdownPreviewScale = min(markdownPreviewScale + 0.1, 3.0) }
                    )
                )
                items.append(
                    previewToolbarIconItem(
                        id: "md-zoom-out",
                        title: "缩小（整体）",
                        systemImage: "minus.magnifyingglass",
                        isDisabled: markdownPreviewScale <= 0.5,
                        action: { [self] in markdownPreviewScale = max(markdownPreviewScale - 0.1, 0.5) }
                    )
                )
                items.append(
                    PreviewToolbarOverflowModel(
                        id: "md-scale",
                        menuTitle: "缩放比例",
                        menuSystemImage: "percent",
                        isDisabled: false,
                        estimatedWidth: 44,
                        menuAction: {},
                        content: AnyView(
                            Text("\(Int((markdownPreviewScale * 100).rounded()))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                        )
                    )
                )
            } else {
                items.append(
                    previewToolbarIconItem(
                        id: "md-font-up",
                        title: "放大字体",
                        systemImage: "plus.magnifyingglass",
                        action: { [self] in markdownSourceFontSize = min(markdownSourceFontSize + 1, 28) }
                    )
                )
                items.append(
                    previewToolbarIconItem(
                        id: "md-font-down",
                        title: "缩小字体",
                        systemImage: "minus.magnifyingglass",
                        isDisabled: markdownSourceFontSize <= 9,
                        action: { [self] in markdownSourceFontSize = max(markdownSourceFontSize - 1, 9) }
                    )
                )
                items.append(
                    PreviewToolbarOverflowModel(
                        id: "md-font-size",
                        menuTitle: "字体大小",
                        menuSystemImage: "textformat.size",
                        isDisabled: false,
                        estimatedWidth: 44,
                        menuAction: {},
                        content: AnyView(
                            Text("\(Int(markdownSourceFontSize.rounded()))pt")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                        )
                    )
                )
            }
        }

        if PreviewTypeClassifier.isHtmlFile(ext) {
            items.append(
                previewToolbarIconItem(
                    id: "html-preview",
                    title: "HTML 解析预览",
                    systemImage: htmlMode == .preview ? "globe.americas.fill" : "globe.americas",
                    action: { [self] in htmlMode = .preview }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "html-source",
                    title: "源码模式",
                    systemImage: htmlMode == .source ? "doc.plaintext.fill" : "doc.plaintext",
                    action: { [self] in htmlMode = .source }
                )
            )
        }

        items.append(
            previewToolbarIconItem(
                id: "text-copy",
                title: "复制全文",
                systemImage: "doc.on.doc",
                action: { [self] in textPreviewAction = .copyAll }
            )
        )
        items.append(
            previewToolbarIconItem(
                id: "text-top",
                title: "跳转顶部",
                systemImage: "arrow.up.to.line",
                action: { [self] in textPreviewAction = .scrollTop }
            )
        )
        items.append(
            previewToolbarIconItem(
                id: "text-bottom",
                title: "跳转底部",
                systemImage: "arrow.down.to.line",
                action: { [self] in textPreviewAction = .scrollBottom }
            )
        )

        return items
    }

    func previewMediaToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "media-play",
                title: mediaIsPlaying ? "暂停" : "播放",
                systemImage: mediaIsPlaying ? "pause.fill" : "play.fill",
                action: { [self] in mediaControlAction = .togglePlayPause }
            ),
            previewToolbarIconItem(
                id: "media-mute",
                title: mediaIsMuted ? "取消静音" : "静音",
                systemImage: mediaIsMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                action: { [self] in mediaControlAction = .toggleMute }
            ),
        ]
    }

    func previewOfficeToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "office-prev",
                title: "上一页（滚动）",
                systemImage: "chevron.left",
                action: { [self] in officeNavigateAction = .pageUp }
            ),
            previewToolbarIconItem(
                id: "office-zoom-out",
                title: "缩小",
                systemImage: "minus.magnifyingglass",
                isDisabled: officeScalePercent > 0 && officeScalePercent <= 25,
                action: { [self] in officeNavigateAction = .zoomOut }
            ),
            PreviewToolbarOverflowModel(
                id: "office-scale",
                menuTitle: "缩放比例",
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text(officeScalePercent > 0 ? "\(officeScalePercent)%" : "--")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                )
            ),
            previewToolbarIconItem(
                id: "office-zoom-in",
                title: "放大",
                systemImage: "plus.magnifyingglass",
                isDisabled: officeScalePercent >= 500,
                action: { [self] in officeNavigateAction = .zoomIn }
            ),
            previewToolbarIconItem(
                id: "office-actual-size",
                title: "100% 还原",
                systemImage: "1.magnifyingglass",
                action: { [self] in officeNavigateAction = .actualSize }
            ),
            previewToolbarIconItem(
                id: "office-fit-width",
                title: "适配宽度",
                systemImage: "arrow.left.and.right.square",
                action: { [self] in officeNavigateAction = .fitWidth }
            ),
            previewToolbarIconItem(
                id: "office-fit-page",
                title: "整页适配",
                systemImage: "arrow.up.left.and.arrow.down.right",
                action: { [self] in officeNavigateAction = .fitPage }
            ),
            previewToolbarIconItem(
                id: "office-next",
                title: "下一页（滚动）",
                systemImage: "chevron.right",
                action: { [self] in officeNavigateAction = .pageDown }
            ),
            previewToolbarIconItem(
                id: "office-open",
                title: "用默认应用打开",
                systemImage: "arrow.up.forward.app",
                action: { NSWorkspace.shared.open(item.url) }
            ),
            previewToolbarIconItem(
                id: "office-reload",
                title: "刷新预览",
                systemImage: "arrow.clockwise",
                action: { [self] in officeReloadToken += 1 }
            ),
        ]
    }

    func previewArchiveToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "archive-reload",
                title: "刷新目录",
                systemImage: "arrow.clockwise",
                action: { [self] in archiveReloadToken += 1 }
            ),
            previewToolbarIconItem(
                id: "archive-expand",
                title: archiveExpanded ? "折叠到第一层" : "展开到全部层级",
                systemImage: archiveExpanded ? "chevron.down" : "chevron.right",
                action: { [self] in archiveExpanded.toggle() }
            ),
            previewToolbarIconItem(
                id: "archive-copy",
                title: "复制清单",
                systemImage: "doc.on.doc",
                action: { [self] in archiveCopyAction = .copyList }
            ),
        ]
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

private struct PreviewImageZoomToolbarControls: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 2) {
            Button {
                session.imageZoomScale = max(session.imageZoomScale - 0.25, 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("缩小")
            .disabled(session.imageZoomScale <= 0.1)

            Button {
                session.imageZoomScale = min(session.imageZoomScale + 0.25, 5.0)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("放大")

            Button {
                session.imageZoomAction = .fit
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help("适配窗口")

            Button {
                session.imageZoomAction = .actualSize
            } label: {
                Image(systemName: "1.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("原始大小")

            Text(session.imageEffectiveZoomPercent > 0 ? "\(session.imageEffectiveZoomPercent)%" : "--")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 36, alignment: .center)
        }
    }
}

private struct PreviewImageEyedropperToolbarButton: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        Button {
            session.imageEyedropperActive.toggle()
        } label: {
            Image(systemName: "eyedropper")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    session.imageEyedropperActive ? Color.accentColor : Color.primary,
                    Color.primary
                )
        }
        .buttonStyle(.borderless)
        .help("取色棒（点击图像复制 Web 颜色）")
    }
}

private struct PreviewImageColorSwatch: View {
    let hex: String
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(session.colorFromWebHex(hex))
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
            Text(hex)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .help("已复制到剪贴板")
    }
}

private struct PreviewPDFPageInputField: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $session.pdfPageInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 44)
                .onSubmit {
                    let trimmed = session.pdfPageInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let page = Int(trimmed), session.pdfPageCount > 0 else {
                        session.pdfPageInput = session.pdfCurrentPage > 0 ? "\(session.pdfCurrentPage)" : ""
                        return
                    }
                    let clamped = min(max(page, 1), session.pdfPageCount)
                    session.pdfNavigateAction = .goToPage(clamped)
                }

            Text("/\(session.pdfPageCount > 0 ? "\(session.pdfPageCount)" : "--")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 74, alignment: .center)
    }
}
