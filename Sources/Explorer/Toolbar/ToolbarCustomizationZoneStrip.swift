import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ToolbarInsertPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(
                Color.accentColor,
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            )
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
            .frame(
                width: ExplorerToolbarMetrics.iconHitSize,
                height: ExplorerToolbarMetrics.iconHitSize
            )
    }
}

/// 拖放悬停会话：松手后置 `hasEnded`，忽略后续误触的 draggingUpdated，避免占位框复活。
@MainActor
private final class ToolbarZoneDragHoverSession: ObservableObject {
    @Published private(set) var insertIndex: Int?
    private var hasEnded = true

    var isActive: Bool { insertIndex != nil }

    func begin(at index: Int) {
        hasEnded = false
        if insertIndex != index {
            insertIndex = index
        }
    }

    func move(to index: Int) {
        guard !hasEnded else { return }
        if insertIndex != index {
            insertIndex = index
        }
    }

    func end() {
        hasEnded = true
        if insertIndex != nil {
            insertIndex = nil
        }
    }
}

struct ToolbarCustomizationZoneStrip<Cell: View>: View {
    let zone: ToolbarZone
    let entries: [ToolbarVisibleEntry]
    @ObservedObject var store: ToolbarCustomizationStore
    @ViewBuilder let cell: (ToolbarVisibleEntry, Int) -> Cell

    @StateObject private var dragHover = ToolbarZoneDragHoverSession()

    private var entryIDs: [String] {
        entries.map(\.id)
    }

    var body: some View {
        // AppKit 落点：关闭系统「飘到目标」的拖影；SwiftUI onDrop 无法设置 animatesToDestination。
        ToolbarZoneAppKitDropContainer(
            itemCount: entries.count,
            zone: zone,
            store: store,
            dragHover: dragHover
        ) {
            Group {
                if entries.isEmpty {
                    emptyDropSurface
                } else {
                    populatedStrip
                }
            }
            .transaction { $0.disablesAnimations = true }
        }
        .onChange(of: entryIDs) { _ in
            dragHover.end()
        }
    }

    private var emptyDropSurface: some View {
        ZStack {
            if dragHover.isActive {
                ToolbarInsertPlaceholder()
            }
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
                if dragHover.insertIndex == slot {
                    ToolbarInsertPlaceholder()
                }

                if slot < entries.count {
                    cell(entries[slot], slot)
                }
            }
        }
        .frame(minHeight: ExplorerToolbarMetrics.iconHitSize)
        .contentShape(Rectangle())
    }
}

// MARK: - AppKit drop

@MainActor
private protocol ToolbarZoneDropHandling: AnyObject {
    var dragHover: ToolbarZoneDragHoverSession { get }
    var itemCount: Int { get }
    func handleDrop(pasteboard: NSPasteboard, insertIndex: Int) -> Bool
}

private struct ToolbarZoneAppKitDropContainer<Content: View>: NSViewRepresentable {
    let itemCount: Int
    let zone: ToolbarZone
    let store: ToolbarCustomizationStore
    let dragHover: ToolbarZoneDragHoverSession
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(
            itemCount: itemCount,
            zone: zone,
            store: store,
            dragHover: dragHover
        )
    }

    func makeNSView(context: Context) -> ToolbarZoneDropNSView {
        let view = ToolbarZoneDropNSView()
        view.handler = context.coordinator

        let hosting = NSHostingView(rootView: content())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        context.coordinator.hostingView = hosting
        return view
    }

    func updateNSView(_ nsView: ToolbarZoneDropNSView, context: Context) {
        context.coordinator.itemCount = itemCount
        context.coordinator.zone = zone
        context.coordinator.store = store
        context.coordinator.dragHover = dragHover
        nsView.handler = context.coordinator
        context.coordinator.hostingView?.rootView = content()
    }

    @MainActor
    final class Coordinator: ToolbarZoneDropHandling {
        var itemCount: Int
        var zone: ToolbarZone
        var store: ToolbarCustomizationStore
        var dragHover: ToolbarZoneDragHoverSession
        var hostingView: NSHostingView<Content>?

        init(
            itemCount: Int,
            zone: ToolbarZone,
            store: ToolbarCustomizationStore,
            dragHover: ToolbarZoneDragHoverSession
        ) {
            self.itemCount = itemCount
            self.zone = zone
            self.store = store
            self.dragHover = dragHover
        }

        func handleDrop(pasteboard: NSPasteboard, insertIndex: Int) -> Bool {
            dragHover.end()

            if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String] {
                for string in strings {
                    if let payload = ToolbarDragPayload.fromPasteboardString(string) {
                        applyLayoutChange {
                            store.applyDrop(
                                payload: payload,
                                targetZone: zone,
                                insertIndex: insertIndex
                            )
                        }
                        return true
                    }
                }
            }

            let urls = FileDragDrop.fileURLs(from: pasteboard)
            guard !urls.isEmpty else { return false }
            applyLayoutChange {
                store.addOpenShortcuts(urls: urls, zone: zone, at: insertIndex)
            }
            return true
        }

        private func applyLayoutChange(_ body: () -> Void) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, body)
        }
    }
}

private final class ToolbarZoneDropNSView: NSView {
    weak var handler: (any ToolbarZoneDropHandling)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.acceptedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let acceptedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        NSPasteboard.PasteboardType(UTType.fileURL.identifier),
        .string,
        NSPasteboard.PasteboardType(UTType.plainText.identifier),
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
        NSPasteboard.PasteboardType("public.utf8-plain-text"),
    ]

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        disableDropAnimation(sender)
        updateHover(with: sender)
        return dragOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        disableDropAnimation(sender)
        updateHover(with: sender)
        return dragOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        handler?.dragHover.end()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        disableDropAnimation(sender)
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        disableDropAnimation(sender)
        guard let handler else { return false }
        let point = convert(sender.draggingLocation, from: nil)
        let insertIndex = ToolbarInsertionIndexResolver.resolve(
            at: point.x,
            itemCount: handler.itemCount
        )
        return handler.handleDrop(pasteboard: sender.draggingPasteboard, insertIndex: insertIndex)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        if let sender {
            disableDropAnimation(sender)
        }
        handler?.dragHover.end()
    }

    private func disableDropAnimation(_ sender: NSDraggingInfo) {
        sender.animatesToDestination = false
    }

    private func updateHover(with sender: NSDraggingInfo) {
        guard let handler else { return }
        let point = convert(sender.draggingLocation, from: nil)
        let index = ToolbarInsertionIndexResolver.resolve(at: point.x, itemCount: handler.itemCount)
        if handler.dragHover.isActive {
            handler.dragHover.move(to: index)
        } else {
            handler.dragHover.begin(at: index)
        }
    }

    private func dragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if pb.availableType(from: [.string, NSPasteboard.PasteboardType(UTType.plainText.identifier)]) != nil {
            return .move
        }
        if !FileDragDrop.fileURLs(from: pb).isEmpty {
            return .copy
        }
        return []
    }
}

private enum ToolbarInsertionIndexResolver {
    static func resolve(at x: CGFloat, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        let stride = ExplorerToolbarMetrics.iconHitSize + ExplorerToolbarMetrics.iconSpacing
        for index in 0..<itemCount {
            let chipMidX = CGFloat(index) * stride + ExplorerToolbarMetrics.iconHitSize * 0.5
            if x < chipMidX {
                return index
            }
        }
        return itemCount
    }
}
