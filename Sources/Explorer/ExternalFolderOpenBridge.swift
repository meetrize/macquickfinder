import SwiftUI

/// 在任意窗口场景挂载，确保外部打开文件夹时能调用 `openWindow`。
struct ExternalFolderOpenBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                ExternalFolderOpenCenter.shared.setOpenFolderWindowHandler { path in
                    openWindow(id: ExplorerWindowScene.folder, value: path)
                }
            }
    }
}
