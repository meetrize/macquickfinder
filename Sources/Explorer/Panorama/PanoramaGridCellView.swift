import AppKit
import FileList
import SwiftUI

struct PanoramaGridCellView: View {
    let row: FileListRow
    let image: NSImage?
    let cellSize: CGFloat
    let isSelected: Bool
    let isCollapsedFolder: Bool
    let isExpandedFolder: Bool
    let rowHoverHighlight: Bool
    let onTap: () -> Void
    let onCommandTap: () -> Void
    let onDoubleTap: () -> Void
    let onCollapseFolder: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var cellBackground: Color {
        let isDark = colorScheme == .dark
        if let tint = FileListThumbnailTypeTint.backgroundColor(for: row, isDark: isDark) {
            return Color(nsColor: tint).opacity(isDark ? 0.92 : 0.88)
        }
        return isDark ? Color(white: 0.16) : Color(white: 0.84)
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor }
        if rowHoverHighlight, isHovered { return Color.accentColor.opacity(0.55) }
        return colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.18)
    }

    private var borderWidth: CGFloat {
        isSelected ? FileListThumbnailMetrics.selectionBorderWidth : 1
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(
                    cornerRadius: FileListThumbnailMetrics.cellCornerRadius,
                    style: .continuous
                )
                .fill(cellBackground)

                thumbnailContent
                    .padding(cellSize * FileListThumbnailMetrics.iconContentInsetRatio)

                if isSelected {
                    RoundedRectangle(
                        cornerRadius: FileListThumbnailMetrics.cellCornerRadius,
                        style: .continuous
                    )
                    .fill(Color.accentColor.opacity(0.15))
                }

                bottomLabelOverlay

                if isExpandedFolder {
                    collapseBadge
                } else if isCollapsedFolder {
                    expandBadge
                }
            }
            .frame(width: cellSize, height: cellSize)
            .overlay(alignment: .topTrailing) {
                if row.isExpanding {
                    ProgressView()
                        .controlSize(.small)
                        .padding(6)
                } else {
                    sizeBadge
                        .padding(4)
                }
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: FileListThumbnailMetrics.cellCornerRadius,
                    style: .continuous
                )
                .strokeBorder(borderColor, lineWidth: borderWidth)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .instantHoverTooltip(row.name)
        .accessibilityLabel(row.name)
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: row.isDirectory ? .fit : .fill)
                .clipped()
        } else {
            Image(systemName: row.isDirectory ? "folder" : "doc")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: cellSize * 0.28, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var bottomLabelOverlay: some View {
        Text(row.name)
            .font(.system(size: 11))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.45))
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var sizeBadge: some View {
        if let badge = badgeText {
            Text(badge)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.45))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private var expandBadge: some View {
        Image(systemName: "chevron.right.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.accentColor)
            .font(.system(size: max(16, cellSize * 0.18)))
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var collapseBadge: some View {
        Button {
            onCollapseFolder?()
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor)
                .font(.system(size: max(16, cellSize * 0.18)))
                .padding(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Panorama.collapseFolder)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var badgeText: String? {
        if row.isDirectory, let count = row.childCountDisplay, !count.isEmpty {
            return count
        }
        if !row.isDirectory, row.size >= 0 {
            return FileListThumbnailMetrics.compactSizeDisplay(bytes: row.size)
        }
        return nil
    }

    private func handleTap() {
        if NSEvent.modifierFlags.contains(.command) {
            onCommandTap()
        } else {
            onTap()
        }
    }
}
