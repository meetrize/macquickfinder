import SwiftUI

/// 文件列表面板布局：左侧表格区（默认 90%）+ 右侧空白区（默认 10%）+ 满宽表头装饰。
public struct FileListPanelLayout<TableContent: View>: View {
    public let rowCount: Int
    public let rowID: (Int) -> String?
    @Binding public var selection: Set<String>
    public let menuActions: FileListBlankMenuActions
    public let onBlankSingleClick: () -> Void
    public let onBlankDoubleClick: () -> Void
    public let blankAreaFraction: CGFloat
    @ViewBuilder public let tableContent: () -> TableContent
    
    public init(
        rowCount: Int,
        rowID: @escaping (Int) -> String?,
        selection: Binding<Set<String>>,
        menuActions: FileListBlankMenuActions,
        onBlankSingleClick: @escaping () -> Void,
        onBlankDoubleClick: @escaping () -> Void,
        blankAreaFraction: CGFloat = FileListLayoutMetrics.blankAreaFraction,
        @ViewBuilder tableContent: @escaping () -> TableContent
    ) {
        self.rowCount = rowCount
        self.rowID = rowID
        _selection = selection
        self.menuActions = menuActions
        self.onBlankSingleClick = onBlankSingleClick
        self.onBlankDoubleClick = onBlankDoubleClick
        self.blankAreaFraction = blankAreaFraction
        self.tableContent = tableContent
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let blankWidth = totalWidth * blankAreaFraction
            let tableWidth = totalWidth - blankWidth
            
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    tableContent()
                        .frame(width: tableWidth)
                    
                    FileListBlankAreaView(
                        rowCount: rowCount,
                        rowID: rowID,
                        selection: $selection,
                        menuActions: menuActions,
                        onSingleClick: onBlankSingleClick,
                        onDoubleClick: onBlankDoubleClick
                    )
                    .frame(width: blankWidth)
                }
                
                FileListHeaderChrome(width: totalWidth)
            }
        }
    }
}
