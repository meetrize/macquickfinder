import SwiftUI

struct PreviewBrowseCommands {
    var canBrowsePrevious: Bool = false
    var canBrowseNext: Bool = false
    var browsePrevious: (() -> Void)?
    var browseNext: (() -> Void)?
    var canToggleStrip: Bool = false
    var isStripExpanded: Bool = false
    var toggleStrip: (() -> Void)?
}

private struct PreviewBrowseCommandsKey: FocusedValueKey {
    typealias Value = PreviewBrowseCommands
}

extension FocusedValues {
    var previewBrowseCommands: PreviewBrowseCommands? {
        get { self[PreviewBrowseCommandsKey.self] }
        set { self[PreviewBrowseCommandsKey.self] = newValue }
    }
}
