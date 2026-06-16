import SwiftUI

/// 横跨整个文件列表面板宽度的表头背景与底部分割线（含右侧 10% 空白区上方）。
public struct FileListHeaderChrome: View {
    public let width: CGFloat
    public var blankAreaFraction: CGFloat = FileListLayoutMetrics.blankAreaFraction
    public var headerHeight: CGFloat = FileListLayoutMetrics.tableHeaderHeight
    
    public init(
        width: CGFloat,
        blankAreaFraction: CGFloat = FileListLayoutMetrics.blankAreaFraction,
        headerHeight: CGFloat = FileListLayoutMetrics.tableHeaderHeight
    ) {
        self.width = width
        self.blankAreaFraction = blankAreaFraction
        self.headerHeight = headerHeight
    }
    
    public var body: some View {
        let blankWidth = width * blankAreaFraction
        let tableWidth = width - blankWidth
        
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 左侧留给 NSTableHeaderView 绘制列标题，不可铺底色遮挡文字。
                Color.clear
                    .frame(width: tableWidth, height: headerHeight)
                Color(nsColor: .controlBackgroundColor)
                    .frame(width: blankWidth, height: headerHeight)
            }
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .frame(width: width, alignment: .leading)
        .allowsHitTesting(false)
    }
}
