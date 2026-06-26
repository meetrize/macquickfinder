import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ToolbarInsertPlaceholder: View {
    let isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(
                isActive ? Color.accentColor : Color.clear,
                style: StrokeStyle(lineWidth: 1.5, dash: isActive ? [4, 3] : [])
            )
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .frame(
                width: ExplorerToolbarMetrics.iconHitSize,
                height: ExplorerToolbarMetrics.iconHitSize
            )
            .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

struct ToolbarChipBounds: Equatable {
    var minX: CGFloat
    var maxX: CGFloat
}

struct ToolbarChipBoundsKey: PreferenceKey {
    static var defaultValue: [Int: ToolbarChipBounds] = [:]

    static func reduce(value: inout [Int: ToolbarChipBounds], nextValue: () -> [Int: ToolbarChipBounds]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ToolbarCustomizationZoneStrip<Cell: View>: View {
    let zone: ToolbarZone
    let entries: [ToolbarVisibleEntry]
    @ObservedObject var store: ToolbarCustomizationStore
    @ViewBuilder let cell: (ToolbarVisibleEntry, Int) -> Cell

    @State private var hoverInsertIndex: Int?
    @State private var isZoneTargeted = false
    @State private var chipBounds: [Int: ToolbarChipBounds] = [:]

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyDropSurface
            } else {
                populatedStrip
            }
        }
        .onDrop(of: [.plainText], delegate: ToolbarZoneDropDelegate(
            hoverInsertIndex: $hoverInsertIndex,
            isZoneTargeted: $isZoneTargeted,
            itemCount: entries.count,
            chipBounds: chipBounds,
            zone: zone,
            store: store
        ))
    }

  private var emptyDropSurface: some View {
        ZStack {
            ToolbarInsertPlaceholder(isActive: isZoneTargeted)
        }
        .frame(
            minWidth: ExplorerToolbarMetrics.iconHitSize * 2,
            minHeight: ExplorerToolbarMetrics.iconHitSize
        )
        .contentShape(Rectangle())
    }

    private var populatedStrip: some View {
        HStack(alignment: .center, spacing: ExplorerToolbarMetrics.iconSpacing) {
            ForEach(0...entries.count, id: \.self) { slot in
                if isZoneTargeted && hoverInsertIndex == slot {
                    ToolbarInsertPlaceholder(isActive: true)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                if slot < entries.count {
                    cell(entries[slot], slot)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ToolbarChipBoundsKey.self,
                                    value: [
                                        slot: ToolbarChipBounds(
                                            minX: proxy.frame(in: .named(zoneCoordinateSpace)).minX,
                                            maxX: proxy.frame(in: .named(zoneCoordinateSpace)).maxX
                                        ),
                                    ]
                                )
                            }
                        }
                }
            }
        }
        .coordinateSpace(name: zoneCoordinateSpace)
        .onPreferenceChange(ToolbarChipBoundsKey.self) { chipBounds = $0 }
        .frame(minHeight: ExplorerToolbarMetrics.iconHitSize)
        .contentShape(Rectangle())
    }

    private var zoneCoordinateSpace: String {
        "toolbar-zone-\(zone.rawValue)"
    }
}

private struct ToolbarZoneDropDelegate: DropDelegate {
    @Binding var hoverInsertIndex: Int?
    @Binding var isZoneTargeted: Bool
    let itemCount: Int
    let chipBounds: [Int: ToolbarChipBounds]
    let zone: ToolbarZone
    let store: ToolbarCustomizationStore

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    func dropEntered(info: DropInfo) {
        isZoneTargeted = true
        updateHoverIndex(at: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isZoneTargeted = true
        updateHoverIndex(at: info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        isZoneTargeted = false
        hoverInsertIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        let insertIndex = hoverInsertIndex ?? itemCount
        guard let provider = info.itemProviders(for: [.plainText]).first else {
            resetHover()
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                defer { resetHover() }
                guard let payload = ToolbarDragPayload.fromPasteboardItem(item) else { return }
                store.applyDrop(payload: payload, targetZone: zone, insertIndex: insertIndex)
            }
        }
        return true
    }

    private func updateHoverIndex(at location: CGPoint) {
        hoverInsertIndex = ToolbarInsertionIndexResolver.resolve(
            at: location.x,
            chipBounds: chipBounds,
            itemCount: itemCount
        )
    }

    private func resetHover() {
        isZoneTargeted = false
        hoverInsertIndex = nil
    }
}

private enum ToolbarInsertionIndexResolver {
    static func resolve(
        at x: CGFloat,
        chipBounds: [Int: ToolbarChipBounds],
        itemCount: Int
    ) -> Int {
        guard itemCount > 0 else { return 0 }

        for index in 0..<itemCount {
            guard let bounds = chipBounds[index] else { continue }
            if x < bounds.minX + (bounds.maxX - bounds.minX) * 0.5 {
                return index
            }
        }
        return itemCount
    }
}
