import AppKit
import Foundation

public enum FileListLayoutMetrics {
    /// 右侧空白区占面板总宽的比例。
    public static let blankAreaFraction: CGFloat = 0.10
    
    /// 与 SwiftUI `Table` / `NSTableView` 表头高度对齐（Phase 2 可改为实测）。
    public static let tableHeaderHeight: CGFloat = 24
    
    /// 右侧空白区中留给垂直滚动条叠放的最小宽度（空白区交互宽度 = blankArea − 此值）。
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
