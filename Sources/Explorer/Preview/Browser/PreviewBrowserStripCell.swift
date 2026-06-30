import AppKit
import FileList
import SwiftUI

struct PreviewBrowserStripCell: View {
    let item: FileItem
    let image: NSImage?
    let distanceFromCenter: Int
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat {
        PreviewBrowserStripMetrics.scale(forDistanceFromCenter: distanceFromCenter)
    }

    private var cellOpacity: CGFloat {
        PreviewBrowserStripMetrics.opacity(forDistanceFromCenter: distanceFromCenter)
    }

    private var defaultCellBackground: Color {
        // 让白色缩略图/图标也能和背景明显区分
        colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.84)
    }

    private var cellBackground: Color {
        let row = FileListRow(item: item)
        let isDark = colorScheme == .dark
        if let tint = FileListThumbnailTypeTint.backgroundColor(for: row, isDark: isDark) {
            // 加深一点以便在胶片条里更容易区分相邻项
            return Color(nsColor: tint).opacity(isDark ? 0.92 : 0.88)
        }
        return defaultCellBackground
    }

    private var cellBorderColor: Color {
        if isSelected { return Color.accentColor }
        return colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.18)
    }

    private var cellBorderWidth: CGFloat {
        isSelected
            ? PreviewBrowserStripMetrics.cellSelectedBorderWidth
            : PreviewBrowserStripMetrics.cellBorderWidth
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: PreviewBrowserStripMetrics.cellCornerRadius,
                    style: .continuous
                )
                .fill(cellBackground)

                Group {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "doc")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.78)
                                    : Color.black.opacity(0.55)
                            )
                    }
                }
                .padding(PreviewBrowserStripMetrics.thumbnailContentInset)
            }
            .frame(
                width: PreviewBrowserStripMetrics.thumbnailSize,
                height: PreviewBrowserStripMetrics.thumbnailSize
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PreviewBrowserStripMetrics.cellCornerRadius,
                    style: .continuous
                )
                .strokeBorder(cellBorderColor, lineWidth: cellBorderWidth)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 1.5, y: 1)
            .scaleEffect(scale)
            .opacity(cellOpacity)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .frame(
            width: PreviewBrowserStripMetrics.thumbnailSize,
            height: PreviewBrowserStripMetrics.thumbnailSize
        )
        .animation(
            .spring(
                response: PreviewBrowserStripMetrics.stripSpringResponse,
                dampingFraction: PreviewBrowserStripMetrics.stripSpringDamping
            ),
            value: distanceFromCenter
        )
        .animation(
            .spring(
                response: PreviewBrowserStripMetrics.stripSpringResponse,
                dampingFraction: PreviewBrowserStripMetrics.stripSpringDamping
            ),
            value: isSelected
        )
        .instantHoverTooltip(item.name)
    }
}
