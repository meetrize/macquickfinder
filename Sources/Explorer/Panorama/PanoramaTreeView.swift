import AppKit
import FileList
import SwiftUI

struct PanoramaTreeView: View {
    @ObservedObject var controller: PanoramaTreeController
    let cellSize: CGFloat
    @Binding var selection: Set<FileItem.ID>
    let rowHoverHighlight: Bool
    let rootItems: [FileItem]
    let onThumbnailCellSizeChange: (CGFloat) -> Void
    let onItemOpen: (FileItem, Bool) -> Void
    let onNavigateToDirectory: (String) -> Void

    @State private var viewportWidth: CGFloat = 800
    @State private var scrollViewport: CGRect = .zero
    @State private var scrollWheelMonitor: Any?

    private var steppedCellSize: CGFloat {
        FileListThumbnailMetrics.steppedCellSize(from: cellSize)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: PanoramaMetrics.sectionVerticalSpacing) {
                    if controller.displayRoot.blocks.isEmpty {
                        panoramaLoadingPlaceholder
                    } else {
                        PanoramaFolderSectionView(
                            blocks: controller.displayRoot.blocks,
                            cellSize: steppedCellSize,
                            viewportWidth: viewportWidth,
                            selection: selection,
                            rowHoverHighlight: rowHoverHighlight,
                            imageForRow: { controller.thumbnailScheduler.image(for: $0) },
                            onCollapse: { controller.toggleCollapse($0) },
                            onEnterDirectory: onNavigateToDirectory,
                            onTap: handleTap,
                            onCommandTap: handleCommandTap,
                            onDoubleTap: handleDoubleTap,
                            onExpandCollapsedFolder: handleExpandCollapsedFolder
                        )
                    }
                }
                .padding(.vertical, PanoramaMetrics.gridContentInset)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                Color.clear
                    .onAppear {
                        updateViewport(from: geometry)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _ in
                        updateViewport(from: geometry)
                    }
            )
            .onPreferenceChange(PanoramaCellFramePreferenceKey.self) { reports in
                controller.submitCellVisibility(
                    cellReports: reports,
                    viewport: scrollViewport
                )
            }
            .onAppear {
                viewportWidth = geometry.size.width
                installScrollWheelMonitor()
                configureThumbnailLoading()
            }
            .onChange(of: geometry.size.width) { newWidth in
                viewportWidth = newWidth
                updateViewport(from: geometry)
            }
            .onChange(of: cellSize) { _ in
                configureThumbnailLoading()
            }
            .onDisappear {
                tearDownScrollWheelMonitor()
            }
        }
    }

    private var panoramaLoadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: PanoramaMetrics.sectionVerticalSpacing) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(
                    cornerRadius: FileListThumbnailMetrics.cellCornerRadius,
                    style: .continuous
                )
                .fill(Color.secondary.opacity(0.10))
                .frame(width: steppedCellSize, height: steppedCellSize)
                .padding(.horizontal, PanoramaMetrics.gridContentInset)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(steppedCellSize), spacing: PanoramaMetrics.gridSpacing),
                        count: 4
                    ),
                    spacing: PanoramaMetrics.gridSpacing
                ) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(
                            cornerRadius: FileListThumbnailMetrics.cellCornerRadius,
                            style: .continuous
                        )
                        .fill(Color.secondary.opacity(0.10))
                        .frame(width: steppedCellSize, height: steppedCellSize)
                    }
                }
                .padding(.horizontal, PanoramaMetrics.gridContentInset)
            }
        }
        .redacted(reason: .placeholder)
    }

    private func updateViewport(from geometry: GeometryProxy) {
        scrollViewport = geometry.frame(in: .global)
    }

    private func configureThumbnailLoading() {
        let screenScale = NSScreen.main?.backingScaleFactor ?? 2
        controller.configureThumbnailLoading(
            cellSize: steppedCellSize,
            screenScale: screenScale,
            preferWorkspaceIcons: false
        )
    }

    private func handleTap(_ row: FileListRow) {
        selection = [row.id]
    }

    private func handleCommandTap(_ row: FileListRow) {
        if selection.contains(row.id) {
            selection.remove(row.id)
        } else {
            selection.insert(row.id)
        }
    }

    private func handleDoubleTap(_ row: FileListRow) {
        guard let item = controller.fileItem(forRowID: row.id, rootItems: rootItems) else { return }
        if item.isDirectory {
            onNavigateToDirectory(item.id)
        } else {
            onItemOpen(item, false)
        }
    }

    private func handleExpandCollapsedFolder(_ row: FileListRow) {
        controller.toggleCollapse(row.id)
    }

    private func installScrollWheelMonitor() {
        tearDownScrollWheelMonitor()
        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            let delta = event.scrollingDeltaY
            guard abs(delta) > 0.5 else { return event }

            let direction: CGFloat = delta > 0 ? 1 : -1
            let next = FileListThumbnailMetrics.steppedCellSize(
                from: cellSize + direction * FileListThumbnailMetrics.cellSizeStep
            )
            guard next != cellSize else { return event }
            onThumbnailCellSizeChange(next)
            return nil
        }
    }

    private func tearDownScrollWheelMonitor() {
        if let scrollWheelMonitor {
            NSEvent.removeMonitor(scrollWheelMonitor)
            self.scrollWheelMonitor = nil
        }
    }
}
