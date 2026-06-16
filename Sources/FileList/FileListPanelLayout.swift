import SwiftUI

/// 文件列表面板布局：表格铺满容器 + 满宽表头底部分割线。
public struct FileListPanelLayout<TableContent: View>: View {
    @ViewBuilder public let tableContent: () -> TableContent
    
    public init(@ViewBuilder tableContent: @escaping () -> TableContent) {
        self.tableContent = tableContent
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                tableContent()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                FileListHeaderChrome(width: geometry.size.width)
            }
        }
    }
}
