import SwiftUI

@MainActor
final class CommandPalettePreviewCommandBridge {
    static let shared = CommandPalettePreviewCommandBridge()

    private struct Entry {
        var detach: PreviewDetachCommands?
        var browse: PreviewBrowseCommands?
    }

    private var entries: [UUID: Entry] = [:]

    private init() {}

    func update(
        hostWindowID: UUID,
        detach: PreviewDetachCommands?,
        browse: PreviewBrowseCommands?
    ) {
        entries[hostWindowID] = Entry(detach: detach, browse: browse)
    }

    func clear(hostWindowID: UUID) {
        entries.removeValue(forKey: hostWindowID)
    }

    func commands(for hostWindowID: UUID) -> (detach: PreviewDetachCommands?, browse: PreviewBrowseCommands?) {
        let entry = entries[hostWindowID]
        return (entry?.detach, entry?.browse)
    }
}

/// 在轻量子视图中订阅 FocusedValue，避免 ContentView 因预览命令变化而整树重绘。
struct CommandPalettePreviewCommandCapture: View {
    let hostWindowID: UUID

    @FocusedValue(\.previewDetachCommands) private var previewDetachCommands
    @FocusedValue(\.previewBrowseCommands) private var previewBrowseCommands

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear(perform: publish)
            .onDisappear {
                CommandPalettePreviewCommandBridge.shared.clear(hostWindowID: hostWindowID)
            }
            .onChange(of: snapshotToken) { _ in
                publish()
            }
    }

    private var snapshotToken: String {
        let detach = previewDetachCommands
        let browse = previewBrowseCommands
        return [
            detach?.canDetach == true ? "1" : "0",
            detach?.canDock == true ? "1" : "0",
            browse?.canBrowsePrevious == true ? "1" : "0",
            browse?.canBrowseNext == true ? "1" : "0",
            browse?.canToggleStrip == true ? "1" : "0",
            browse?.isStripExpanded == true ? "1" : "0",
        ].joined(separator: "-")
    }

    private func publish() {
        CommandPalettePreviewCommandBridge.shared.update(
            hostWindowID: hostWindowID,
            detach: previewDetachCommands,
            browse: previewBrowseCommands
        )
    }
}
