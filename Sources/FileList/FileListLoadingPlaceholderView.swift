import SwiftUI

/// 目录加载中的占位动画，保持与真实文件列表相同的布局区域。
public struct FileListLoadingPlaceholderView: View {
    public let viewMode: FileListViewMode
    public let thumbnailCellSize: CGFloat
    
    public init(viewMode: FileListViewMode, thumbnailCellSize: CGFloat) {
        self.viewMode = viewMode
        self.thumbnailCellSize = thumbnailCellSize
    }
    
    public var body: some View {
        Group {
            switch viewMode {
            case .list:
                listPlaceholder
            case .thumbnail:
                thumbnailPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityLabel("正在加载文件列表")
    }
    
    private var listPlaceholder: some View {
        GeometryReader { geometry in
            let rowHeight: CGFloat = 24
            let rowCount = max(8, Int(ceil(geometry.size.height / rowHeight)))
            
            VStack(spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { index in
                    HStack(spacing: 12) {
                        FileListSkeletonBlock(width: 18, height: 18, cornerRadius: 4)
                            .shimmer(delay: Double(index) * 0.04)
                        
                        FileListSkeletonBlock(
                            width: geometry.size.width * CGFloat.random(in: 0.22...0.42, seed: index),
                            height: 12,
                            cornerRadius: 3
                        )
                        .shimmer(delay: Double(index) * 0.04 + 0.05)
                        
                        Spacer(minLength: 0)
                        
                        FileListSkeletonBlock(width: 52, height: 10, cornerRadius: 3)
                            .shimmer(delay: Double(index) * 0.04 + 0.1)
                        
                        FileListSkeletonBlock(width: 88, height: 10, cornerRadius: 3)
                            .shimmer(delay: Double(index) * 0.04 + 0.15)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: rowHeight)
                    
                    if index < rowCount - 1 {
                        Divider()
                            .padding(.leading, 42)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private var thumbnailPlaceholder: some View {
        GeometryReader { geometry in
            let cellSize = FileListThumbnailMetrics.steppedCellSize(from: thumbnailCellSize)
            let spacing = FileListThumbnailMetrics.cellSpacing
            let inset = FileListThumbnailMetrics.contentInset
            let availableWidth = max(0, geometry.size.width - inset * 2)
            let cellStride = cellSize + spacing
            let columnCount = max(1, Int(floor((availableWidth + spacing) / cellStride)))
            let rowCount = max(
                3,
                Int(ceil((geometry.size.height - inset * 2 + spacing) / cellStride))
            )
            let totalItems = columnCount * rowCount
            
            let columns = Array(
                repeating: GridItem(.fixed(cellSize), spacing: spacing, alignment: .top),
                count: columnCount
            )
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(0..<totalItems, id: \.self) { index in
                        FileListThumbnailSkeletonCell(cellSize: cellSize)
                            .shimmer(delay: Double(index % columnCount) * 0.05)
                    }
                }
                .padding(inset)
            }
            .scrollDisabled(true)
        }
    }
}

private struct FileListThumbnailSkeletonCell: View {
    let cellSize: CGFloat
    
    var body: some View {
        VStack(spacing: 6) {
            FileListSkeletonBlock(
                width: cellSize,
                height: cellSize,
                cornerRadius: FileListThumbnailMetrics.cellCornerRadius
            )
            
            FileListSkeletonBlock(
                width: cellSize * 0.72,
                height: 10,
                cornerRadius: 3
            )
        }
        .frame(width: cellSize)
    }
}

private struct FileListSkeletonBlock: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.55))
            .frame(width: width, height: height)
    }
}

private struct FileListShimmerModifier: ViewModifier {
    let delay: Double
    
    @State private var phase: CGFloat = -1.2
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.28),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.55)
                    .offset(x: geometry.size.width * phase)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 1.15)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    phase = 1.2
                }
            }
    }
}

private extension View {
    func shimmer(delay: Double = 0) -> some View {
        modifier(FileListShimmerModifier(delay: delay))
    }
}

private extension CGFloat {
    static func random(in range: ClosedRange<CGFloat>, seed: Int) -> CGFloat {
        let unit = CGFloat((seed * 1_103_515_245) % 10_000) / 10_000
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
