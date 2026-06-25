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
        colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.90)
    }

    private var cellBackground: Color {
        let row = FileListRow(item: item)
        let isDark = colorScheme == .dark
        if let tint = FileListThumbnailTypeTint.backgroundColor(for: row, isDark: isDark) {
            return Color(nsColor: tint)
        }
        return defaultCellBackground
    }

    private var cellBorderColor: Color {
        isSelected ? Color.accentColor : Color(nsColor: .separatorColor)
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
                            .font(.title2)
                            .foregroundStyle(.tertiary)
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
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 1, y: 1)
            .scaleEffect(scale)
            .opacity(cellOpacity)
        }
        .buttonStyle(.plain)
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
