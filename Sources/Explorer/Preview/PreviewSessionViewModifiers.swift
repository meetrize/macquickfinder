import SwiftUI

/// 内联 / 分离窗口共用的 PreviewSession 交互修饰（PDF 页码同步、图片缩放 sheet、文件夹子项重置）。
struct PreviewSessionInteractionModifiers: ViewModifier {
    @ObservedObject var session: PreviewSession

    func body(content: Content) -> some View {
        content
            .onChange(of: session.folderInlineChild?.id) { _ in
                session.resetControls()
            }
            .onChange(of: session.pdf.currentPage) { newValue in
                if newValue > 0 {
                    session.pdf.pageInput = "\(newValue)"
                } else {
                    session.pdf.pageInput = ""
                }
            }
            .sheet(isPresented: $session.image.showResizeSheet) {
                let dialogSize = session.image.resizeDialogSize
                let oriented = session.image.effectiveOrientedPixelSize
                ImageResizeSheet(
                    initialWidth: dialogSize.width,
                    initialHeight: dialogSize.height,
                    aspectWidth: max(1, Int(oriented.width.rounded())),
                    aspectHeight: max(1, Int(oriented.height.rounded())),
                    onCancel: { session.image.showResizeSheet = false },
                    onApply: { width, height in
                        session.image.performEdit {
                            session.image.resizeTargetSize = CGSize(width: width, height: height)
                        }
                        session.image.zoomScale = 1.0
                        session.image.zoomAction = .fit
                        session.image.showResizeSheet = false
                    }
                )
            }
            .onChange(of: session.image.editUndoClearNonce) { _ in
                session.image.clearEditUndoStack()
            }
    }
}

extension View {
    func previewSessionInteractions(_ session: PreviewSession) -> some View {
        modifier(PreviewSessionInteractionModifiers(session: session))
    }
}
