import SwiftUI
import AppKit

struct ImagePreviewContent: View {
    let image: NSImage
    let fileURL: URL
    @Binding var zoomScale: CGFloat
    @Binding var zoomAction: ImageZoomAction?
    @Binding var effectiveZoomPercent: Int
    @Binding var rotationQuarterTurns: Int
    @Binding var flipHorizontal: Bool
    @Binding var flipVertical: Bool
    @Binding var resizeTargetSize: CGSize?
    @Binding var eyedropperActive: Bool
    @Binding var pickedWebColor: String?
    
    @State private var panOffset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let rawImageSize = resolvedImageSize(image)
            let isRotatedSideways = rotationQuarterTurns % 2 != 0
            let orientedSize = isRotatedSideways
                ? CGSize(width: rawImageSize.height, height: rawImageSize.width)
                : rawImageSize
            let layoutImageSize = resizeTargetSize ?? orientedSize
            let resizeScaleX = layoutImageSize.width / max(orientedSize.width, 1)
            let resizeScaleY = layoutImageSize.height / max(orientedSize.height, 1)
            let fitScale = min(
                containerSize.width / max(layoutImageSize.width, 1),
                containerSize.height / max(layoutImageSize.height, 1)
            )
            let imageDisplaySize = CGSize(
                width: rawImageSize.width * fitScale * zoomScale * resizeScaleX,
                height: rawImageSize.height * fitScale * zoomScale * resizeScaleY
            )
            let layoutDisplaySize = CGSize(
                width: layoutImageSize.width * fitScale * zoomScale,
                height: layoutImageSize.height * fitScale * zoomScale
            )
            let currentOffset = clampedPanOffset(
                proposed: CGSize(
                    width: panOffset.width + dragTranslation.width,
                    height: panOffset.height + dragTranslation.height
                ),
                containerSize: containerSize,
                displaySize: layoutDisplaySize
            )
            
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaleEffect(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
                    .rotationEffect(.degrees(Double(rotationQuarterTurns) * 90))
                    .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
                    .offset(x: currentOffset.width, y: currentOffset.height)
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
            .contentShape(Rectangle())
            .contextMenu {
                imagePreviewContextMenu()
            }
            .onHover { isHovering in
                if eyedropperActive && isHovering {
                    NSCursor.crosshair.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(imageInteractionGesture(
                containerSize: containerSize,
                imageDisplaySize: imageDisplaySize,
                layoutDisplaySize: layoutDisplaySize
            ))
            .onAppear {
                let percent = Int((fitScale * zoomScale * 100).rounded())
                effectiveZoomPercent = max(1, min(percent, 1000))
            }
            .onChange(of: zoomScale) { _ in
                let percent = Int((fitScale * zoomScale * 100).rounded())
                effectiveZoomPercent = max(1, min(percent, 1000))
            }
            .onChange(of: resizeTargetSize) { _ in
                let percent = Int((fitScale * zoomScale * 100).rounded())
                effectiveZoomPercent = max(1, min(percent, 1000))
            }
            .onChange(of: zoomAction) { action in
                guard let action else { return }
                switch action {
                case .fit:
                    zoomScale = 1.0
                case .actualSize:
                    zoomScale = max(0.1, min(1.0 / max(fitScale, 0.0001), 5.0))
                }
                DispatchQueue.main.async { zoomAction = nil }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: zoomScale) { _ in
            panOffset = .zero
        }
        .onChange(of: rotationQuarterTurns) { _ in
            panOffset = .zero
        }
        .onChange(of: flipHorizontal) { _ in
            panOffset = .zero
        }
        .onChange(of: flipVertical) { _ in
            panOffset = .zero
        }
        .onChange(of: resizeTargetSize) { _ in
            panOffset = .zero
        }
    }

    @ViewBuilder
    private func imagePreviewContextMenu() -> some View {
        Button {
            ImagePreviewContextActions.openMarkup(for: fileURL)
        } label: {
            Label("标记…", systemImage: "pencil.tip.crop.circle")
        }

        Divider()

        Button {
            ImagePreviewContextActions.copyImage(from: fileURL)
        } label: {
            Label("复制图片", systemImage: "doc.on.doc")
        }

        Button {
            ImagePreviewContextActions.copyPath(fileURL)
        } label: {
            Label("复制路径", systemImage: "link")
        }

        Divider()

        Button {
            ImagePreviewContextActions.revealInFinder(fileURL)
        } label: {
            Label("在 Finder 中显示", systemImage: "folder")
        }

        PreviewOpenWithMenuSection(fileURL: fileURL)

        Divider()

        Button {
            ImagePreviewContextActions.setAsDesktopPicture(fileURL)
        } label: {
            Label("设为桌面图片", systemImage: "photo.on.rectangle.angled")
        }

        ShareLink(item: fileURL, preview: SharePreview(fileURL.lastPathComponent, image: Image(nsImage: image))) {
            Label("共享…", systemImage: "square.and.arrow.up")
        }
    }

    private func imageInteractionGesture(
        containerSize: CGSize,
        imageDisplaySize: CGSize,
        layoutDisplaySize: CGSize
    ) -> some Gesture {
        if eyedropperActive {
            return AnyGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        pickWebColor(
                            at: value.location,
                            containerSize: containerSize,
                            imageDisplaySize: imageDisplaySize
                        )
                    }
            )
        }

        return AnyGesture(
            DragGesture(minimumDistance: 0)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    panOffset = clampedPanOffset(
                        proposed: CGSize(
                            width: panOffset.width + value.translation.width,
                            height: panOffset.height + value.translation.height
                        ),
                        containerSize: containerSize,
                        displaySize: layoutDisplaySize
                    )
                }
        )
    }

    private func pickWebColor(
        at location: CGPoint,
        containerSize: CGSize,
        imageDisplaySize: CGSize
    ) {
        guard let normalizedPoint = normalizedImagePoint(
            at: location,
            containerSize: containerSize,
            imageDisplaySize: imageDisplaySize
        ), let hex = ImagePreviewTransformApplier.sampleWebColor(
            from: image,
            normalizedPoint: normalizedPoint
        ) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
        pickedWebColor = hex
    }

    private func normalizedImagePoint(
        at location: CGPoint,
        containerSize: CGSize,
        imageDisplaySize: CGSize
    ) -> CGPoint? {
        guard imageDisplaySize.width > 0, imageDisplaySize.height > 0 else { return nil }

        let centerX = containerSize.width / 2 + panOffset.width
        let centerY = containerSize.height / 2 + panOffset.height
        var point = CGPoint(x: location.x - centerX, y: location.y - centerY)

        let turns = ((rotationQuarterTurns % 4) + 4) % 4
        if turns != 0 {
            let radians = -Double(turns) * .pi / 2
            let cosValue = cos(radians)
            let sinValue = sin(radians)
            let rotatedX = point.x * cosValue - point.y * sinValue
            let rotatedY = point.x * sinValue + point.y * cosValue
            point = CGPoint(x: rotatedX, y: rotatedY)
        }

        if flipHorizontal { point.x *= -1 }
        if flipVertical { point.y *= -1 }

        let normalizedX = point.x / imageDisplaySize.width + 0.5
        let normalizedY = point.y / imageDisplaySize.height + 0.5
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else {
            return nil
        }
        return CGPoint(x: normalizedX, y: normalizedY)
    }
    
    private func clampedPanOffset(
        proposed: CGSize,
        containerSize: CGSize,
        displaySize: CGSize
    ) -> CGSize {
        let maxX = displaySize.width > containerSize.width
            ? (displaySize.width - containerSize.width) / 2
            : 0
        let maxY = displaySize.height > containerSize.height
            ? (displaySize.height - containerSize.height) / 2
            : 0
        
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
    
    private func resolvedImageSize(_ image: NSImage) -> CGSize {
        if image.size.width > 0, image.size.height > 0 {
            return image.size
        }
        if let rep = image.representations.first {
            return CGSize(width: max(rep.pixelsWide, 1), height: max(rep.pixelsHigh, 1))
        }
        return CGSize(width: 1, height: 1)
    }
}
