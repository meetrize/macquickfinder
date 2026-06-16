import AppKit
import Foundation

public enum FileListLayoutMetrics {
    /// 右侧空白区占面板总宽的比例。
    public static let blankAreaFraction: CGFloat = 0.10
    
    /// 与 SwiftUI `Table` / `NSTableView` 表头高度对齐（Phase 2 可改为实测）。
    public static let tableHeaderHeight: CGFloat = 24
    
    /// `.tableStyle(.inset)` 在表格外侧留出的尾缘，用于抵消后让滚动条贴齐 90% 区域右缘。
    public static let tableStyleTrailingMargin: CGFloat = 12
    
    public static var verticalScrollerWidth: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay)
    }
    
    public static func tableWidth(forTotalWidth totalWidth: CGFloat) -> CGFloat {
        totalWidth * (1 - blankAreaFraction)
    }
    
    public static func blankAreaWidth(forTotalWidth totalWidth: CGFloat) -> CGFloat {
        totalWidth * blankAreaFraction
    }
}
