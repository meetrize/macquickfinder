import SwiftUI

/// 横跨整个文件列表面板宽度的表头底部分割线（列标题由 NSTableHeaderView 绘制）。
public struct FileListHeaderChrome: View {
    public let width: CGFloat
    public var headerHeight: CGFloat = FileListLayoutMetrics.tableHeaderHeight
    
    public init(width: CGFloat, headerHeight: CGFloat = FileListLayoutMetrics.tableHeaderHeight) {
        self.width = width
        self.headerHeight = headerHeight
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: headerHeight)
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .frame(width: width, alignment: .leading)
        .allowsHitTesting(false)
    }
}
