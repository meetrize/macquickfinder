import FileList
import SwiftUI

struct PanoramaOverflowCellView: View {
    let remaining: Int
    let cellSize: CGFloat
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: FileListThumbnailMetrics.cellCornerRadius,
                    style: .continuous
                )
                .fill(Color(nsColor: PanoramaMetrics.cellBackgroundColor(isDark: colorScheme == .dark)))

                VStack(spacing: 6) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: cellSize * 0.22, weight: .bold))
                    Text("+\(remaining)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            .frame(width: cellSize, height: cellSize)
            .overlay {
                RoundedRectangle(
                    cornerRadius: FileListThumbnailMetrics.cellCornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
