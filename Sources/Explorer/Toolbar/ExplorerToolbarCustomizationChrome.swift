import SwiftUI

/// 把工具栏观察范围收窄到本 modifier：`ToolbarCustomizationStore` 变更不再重绘整个文件浏览器。
struct ExplorerToolbarCustomizationChrome<SearchContent: View>: ViewModifier {
    @ObservedObject var store: ToolbarCustomizationStore
    let environment: ExplorerToolbarEnvironment
    @ViewBuilder var searchContent: () -> SearchContent

    func body(content: Content) -> some View {
        content.toolbar {
            ExplorerDynamicToolbar(
                store: store,
                environment: environment,
                searchContent: searchContent
            )
        }
    }
}
