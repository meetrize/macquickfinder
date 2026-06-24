import FileList
import SwiftUI

/// 将用户界面语言偏好注入 SwiftUI 环境，并在切换时强制刷新视图树。
struct InterfaceLanguageEnvironmentModifier: ViewModifier {
    @ObservedObject private var settings = InterfaceLanguageSettings.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, settings.locale)
            .id(settings.revision)
    }
}

extension View {
    func applyInterfaceLanguageEnvironment() -> some View {
        modifier(InterfaceLanguageEnvironmentModifier())
    }
}
