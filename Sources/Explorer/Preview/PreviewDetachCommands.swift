import SwiftUI

struct PreviewDetachCommands {
    var canDetach: Bool = false
    var canDock: Bool = false
    var detachPreview: (() -> Void)?
    var dockPreview: (() -> Void)?
}

private struct PreviewDetachCommandsKey: FocusedValueKey {
    typealias Value = PreviewDetachCommands
}

extension FocusedValues {
    var previewDetachCommands: PreviewDetachCommands? {
        get { self[PreviewDetachCommandsKey.self] }
        set { self[PreviewDetachCommandsKey.self] = newValue }
    }
}
