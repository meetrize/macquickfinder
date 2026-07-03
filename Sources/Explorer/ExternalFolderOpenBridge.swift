import SwiftUI

/// 在任意窗口场景挂载，确保外部打开文件夹时能调用 `openWindow`。
struct ExternalFolderOpenBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                let openFolder: (ExplorerFolderWindowValue) -> Void = { value in
                    openWindow(id: ExplorerWindowScene.folder, value: value)
                }
                ExplorerWindowOpenBridge.shared.openFolderWindow = openFolder
                ExplorerWindowOpenBridge.shared.openMainWindow = {
                    openWindow(id: ExplorerWindowScene.main)
                }
                ExternalFolderOpenCenter.shared.setOpenFolderWindowHandler { request in
                    openFolder(
                        ExplorerFolderWindowValue(
                            path: request.directoryPath,
                            selectionPath: request.selectionPath
                        )
                    )
                }
                let openPreview: (PreviewWindowValue) -> Void = { value in
                    openWindow(id: ExplorerWindowScene.preview, value: value)
                }
                ExplorerWindowOpenBridge.shared.openPreviewWindow = openPreview
                ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler(openPreview)
            }
    }
}
