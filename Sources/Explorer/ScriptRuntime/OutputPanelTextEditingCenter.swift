import Combine
import Foundation

/// 输出面板文本框编辑状态（供 ContentView 菜单快捷键与 AppKit 焦点同步）。
@MainActor
final class OutputPanelTextEditingCenter: ObservableObject {
    static let shared = OutputPanelTextEditingCenter()

    @Published private(set) var isActive = false

    private init() {}

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
    }
}
