import SwiftUI

/// 图片预览剪裁框：可拖动移动与四角/四边缩放。
struct ImageCropOverlayView: View {
    @Binding var normalizedRect: CGRect
    var isInteractive: Bool

    private let handleSize: CGFloat = 10
    private let minNormalizedSide: CGFloat = 0.05

    @State private var dragStartRect: CGRect?

    var body: some View {
        GeometryReader { geo in
            let imageSize = geo.size
            let pixelRect = CGRect(
                x: normalizedRect.minX * imageSize.width,
                y: normalizedRect.minY * imageSize.height,
                width: normalizedRect.width * imageSize.width,
                height: normalizedRect.height * imageSize.height
            )

            ZStack(alignment: .topLeading) {
                CropDimMask(hole: pixelRect, container: CGRect(origin: .zero, size: imageSize))
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    .background(Color.white.opacity(0.001))
                    .frame(width: max(pixelRect.width, 1), height: max(pixelRect.height, 1))
                    .offset(x: pixelRect.minX, y: pixelRect.minY)
                    .gesture(isInteractive ? moveGesture(imageSize: imageSize) : nil)

                if isInteractive {
                    ForEach(CropHandle.allCases, id: \.self) { handle in
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 1))
                            .frame(width: handleSize, height: handleSize)
                            .position(handle.position(in: pixelRect))
                            .gesture(resizeGesture(handle: handle, imageSize: imageSize))
                    }
                }
            }
        }
    }

    private func moveGesture(imageSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartRect ?? normalizedRect
                if dragStartRect == nil {
                    dragStartRect = normalizedRect
                }
                let dx = value.translation.width / max(imageSize.width, 1)
                let dy = value.translation.height / max(imageSize.height, 1)
                var next = start
                next.origin.x += dx
                next.origin.y += dy
                normalizedRect = ImagePreviewTransformApplier.clampedNormalizedCropRect(next)
            }
            .onEnded { _ in
                dragStartRect = nil
            }
    }

    private func resizeGesture(handle: CropHandle, imageSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartRect ?? normalizedRect
                if dragStartRect == nil {
                    dragStartRect = normalizedRect
                }
                let dx = value.translation.width / max(imageSize.width, 1)
                let dy = value.translation.height / max(imageSize.height, 1)
                var r = start
                switch handle {
                case .topLeft:
                    r.origin.x += dx
                    r.origin.y += dy
                    r.size.width -= dx
                    r.size.height -= dy
                case .top:
                    r.origin.y += dy
                    r.size.height -= dy
                case .topRight:
                    r.origin.y += dy
                    r.size.width += dx
                    r.size.height -= dy
                case .right:
                    r.size.width += dx
                case .bottomRight:
                    r.size.width += dx
                    r.size.height += dy
                case .bottom:
                    r.size.height += dy
                case .bottomLeft:
                    r.origin.x += dx
                    r.size.width -= dx
                    r.size.height += dy
                case .left:
                    r.origin.x += dx
                    r.size.width -= dx
                }
                guard r.width >= minNormalizedSide, r.height >= minNormalizedSide else { return }
                normalizedRect = ImagePreviewTransformApplier.clampedNormalizedCropRect(r)
            }
            .onEnded { _ in
                dragStartRect = nil
            }
    }
}

private enum CropHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

private struct CropDimMask: View {
    let hole: CGRect
    let container: CGRect

    var body: some View {
        Path { path in
            path.addRect(container)
            path.addRect(hole)
        }
        .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
    }
}
