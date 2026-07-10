import SwiftUI

/// 全景模式统一左缘内边距行容器，保证折叠网格与展开目录格左侧对齐。
struct PanoramaLeadingInsetRow<Content: View>: View {
    let depth: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            content()
            Spacer(minLength: 0)
        }
        .padding(.leading, PanoramaMetrics.contentLeadingInset(forDepth: depth))
        .padding(.trailing, PanoramaMetrics.contentTrailingInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
