import AppKit
import SwiftUI

struct PreviewBrowserStripCell: View {
    let item: FileItem
    let image: NSImage?
    let distanceFromCenter: Int
    let isSelected: Bool
    let onSelect: () -> Void

    private var scale: CGFloat {
        PreviewBrowserStripMetrics.scale(forDistanceFromCenter: distanceFromCenter)
    }

    private var cellOpacity: CGFloat {
        PreviewBrowserStripMetrics.opacity(forDistanceFromCenter: distanceFromCenter)
    }

    var body: some View {
        Button(action: onSelect) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "doc")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(
                width: PreviewBrowserStripMetrics.thumbnailSize,
                height: PreviewBrowserStripMetrics.thumbnailSize
            )
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
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
        .help(item.name)
    }
}
