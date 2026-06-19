import AppKit
import SwiftUI

struct DetachedPreviewWindowView: View {
    let sessionID: PreviewSessionID

    @ObservedObject private var store = PreviewSessionStore.shared
    @Environment(\.dismiss) private var dismiss

    private var session: PreviewSession? {
        store.session(for: sessionID)
    }

    var body: some View {
        Group {
            if let session {
                DetachedPreviewWindowContent(session: session)
            } else {
                Text("预览会话已关闭")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 320, minHeight: 240)
        .onDisappear {
            PreviewDetachCoordinator.shared.onDetachedWindowWillClose(sessionID: sessionID)
        }
    }
}

private struct DetachedPreviewWindowContent: View {
    @ObservedObject var session: PreviewSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if session.isShowingFolderChildPreview {
                    Button {
                        session.folderInlineChild = nil
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("返回文件夹")
                }

                Text(session.previewContentItem?.name ?? session.file.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 0, maxWidth: 160, alignment: .leading)

                if let item = session.toolbarFileItem {
                    PreviewToolbarOverflowLayout(
                        spacing: 4,
                        items: session.previewToolbarItems(for: item)
                    )
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                } else {
                    Spacer(minLength: 0)
                }

                Button {
                    Task {
                        let docked = await PreviewDetachCoordinator.shared.dockBack(
                            sessionID: session.id,
                            currentSelectedFileID: nil
                        )
                        if docked { dismiss() }
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .help("收回侧栏")

                Button {
                    PreviewDetachCoordinator.shared.onDetachedWindowWillClose(sessionID: session.id)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭窗口")
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .padding(.horizontal, 10)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)

            Divider()

            FileContentView(session: session)
        }
        .navigationTitle(session.previewContentItem?.name ?? session.file.name)
        .onChange(of: session.pdfCurrentPage) { newValue in
            if newValue > 0 {
                session.pdfPageInput = "\(newValue)"
            } else {
                session.pdfPageInput = ""
            }
        }
        .sheet(isPresented: $session.showImageResizeSheet) {
            let dialogSize = session.imageResizeDialogSize
            let oriented = session.imageEffectiveOrientedPixelSize
            ImageResizeSheet(
                initialWidth: dialogSize.width,
                initialHeight: dialogSize.height,
                aspectWidth: max(1, Int(oriented.width.rounded())),
                aspectHeight: max(1, Int(oriented.height.rounded())),
                onCancel: { session.showImageResizeSheet = false },
                onApply: { width, height in
                    session.performImageEdit {
                        session.imageResizeTargetSize = CGSize(width: width, height: height)
                    }
                    session.imageZoomScale = 1.0
                    session.imageZoomAction = .fit
                    session.showImageResizeSheet = false
                }
            )
        }
        .onChange(of: session.imageEditUndoClearNonce) { _ in
            session.clearImageEditUndoStack()
        }
        .background(DetachedPreviewWindowTracker(sessionID: session.id))
    }
}

private struct DetachedPreviewWindowTracker: NSViewRepresentable {
    let sessionID: PreviewSessionID

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
            }
        }
    }
}
