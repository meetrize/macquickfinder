import CoreGraphics
import SwiftUI

struct PanoramaCellVisibility: Equatable, Sendable {
    let rowID: String
    let directoryID: String
    let frame: CGRect
}

struct PanoramaVisibilitySnapshot: Equatable, Sendable {
    let visibleRowIDs: Set<String>
    let visibleDirectoryPaths: Set<String>
    let prefetchDirectoryPaths: Set<String>
    let cellReports: [PanoramaCellVisibility]
}

struct PanoramaCellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PanoramaCellVisibility] { [] }

    static func reduce(value: inout [PanoramaCellVisibility], nextValue: () -> [PanoramaCellVisibility]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func panoramaCellVisibility(
        rowID: String,
        directoryID: String,
        in coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PanoramaCellFramePreferenceKey.self,
                    value: [
                        PanoramaCellVisibility(
                            rowID: rowID,
                            directoryID: directoryID,
                            frame: proxy.frame(in: coordinateSpace)
                        ),
                    ]
                )
            }
        )
    }
}

/// 汇总 cell 可见性并 debounce，供 Controller 与 Scheduler 使用。
@MainActor
final class PanoramaVisibleCellTracker: ObservableObject {
    @Published private(set) var snapshot = PanoramaVisibilitySnapshot(
        visibleRowIDs: [],
        visibleDirectoryPaths: [],
        prefetchDirectoryPaths: [],
        cellReports: []
    )

    var onVisibilityChanged: ((PanoramaVisibilitySnapshot) -> Void)?

    private var debounceWorkItem: DispatchWorkItem?
    private var latestReports: [PanoramaCellVisibility] = []
    private var latestViewport: CGRect = .zero

    func submit(cellReports: [PanoramaCellVisibility], viewport: CGRect) {
        latestReports = cellReports
        latestViewport = viewport

        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.applyLatestVisibility()
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PanoramaMetrics.visibilityDebounce,
            execute: work
        )
    }

    func reset() {
        debounceWorkItem?.cancel()
        latestReports = []
        latestViewport = .zero
        snapshot = PanoramaVisibilitySnapshot(
            visibleRowIDs: [],
            visibleDirectoryPaths: [],
            prefetchDirectoryPaths: [],
            cellReports: []
        )
    }

    // MARK: - Private

    private func applyLatestVisibility() {
        let visibleViewport = latestViewport.insetBy(dx: -24, dy: -48)
        let prefetchViewport = latestViewport.insetBy(dx: -120, dy: -200)

        var visibleRowIDs = Set<String>()
        var visibleDirectoryPaths = Set<String>()
        var prefetchDirectoryPaths = Set<String>()

        for report in latestReports {
            if visibleViewport.intersects(report.frame) {
                visibleRowIDs.insert(report.rowID)
                visibleDirectoryPaths.insert(report.directoryID)
            } else if prefetchViewport.intersects(report.frame) {
                prefetchDirectoryPaths.insert(report.directoryID)
            }
        }

        prefetchDirectoryPaths.subtract(visibleDirectoryPaths)

        let nextSnapshot = PanoramaVisibilitySnapshot(
            visibleRowIDs: visibleRowIDs,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths,
            cellReports: latestReports
        )
        snapshot = nextSnapshot
        onVisibilityChanged?(nextSnapshot)
    }
}

#if DEBUG
extension PanoramaVisibleCellTracker {
    func applyImmediatelyForTesting(
        cellReports: [PanoramaCellVisibility],
        viewport: CGRect
    ) {
        latestReports = cellReports
        latestViewport = viewport
        applyLatestVisibility()
    }
}
#endif
