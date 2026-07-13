import AppKit
import SwiftUI

struct CommandPaletteOverlay: View {
    let session: CommandPaletteSession
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            CommandPaletteView(
                session: session,
                onDismiss: { isPresented = false },
                onExecute: { id in
                    CommandPaletteRegistry.perform(id: id, in: session.context)
                    isPresented = false
                }
            )
            .frame(maxWidth: 560)
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 72)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(100)
    }
}

struct CommandPaletteView: View {
    let session: CommandPaletteSession
    let onDismiss: () -> Void
    let onExecute: (CommandPaletteID) -> Void

    @State private var query = ""
    @State private var displayedItems: [CommandPaletteResolvedItem] = []
    @State private var staticItemCount = 0
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            listSection
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45))
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .onAppear {
            refreshDisplayedItems()
            resetSelection()
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .onChange(of: query) { _ in
            refreshDisplayedItems()
            resetSelection()
        }
        .background(
            CommandPaletteKeyboardMonitor(
                isActive: true,
                onMoveSelection: moveSelection,
                onExecute: executeSelected,
                onDismiss: onDismiss
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "command")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(L10n.CommandPalette.placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var listSection: some View {
        if displayedItems.isEmpty {
            Text(L10n.CommandPalette.noResults)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !hasQuery, !session.recents.isEmpty {
                            sectionHeader(L10n.CommandPalette.recentsSection)
                        } else if !hasQuery {
                            sectionHeader(L10n.CommandPalette.commonSection)
                        }

                        ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                            if shouldShowSnippetsSectionHeader(at: index) {
                                sectionHeader(session.snippetsSectionTitle)
                            }

                            CommandPaletteRow(
                                item: item,
                                isSelected: index == selectedIndex
                            )
                            .id(item.id)
                            .onTapGesture {
                                guard item.isEnabled else { return }
                                selectedIndex = index
                                onExecute(item.id)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
                .onChange(of: selectedIndex) { newIndex in
                    guard displayedItems.indices.contains(newIndex) else { return }
                    proxy.scrollTo(displayedItems[newIndex].id, anchor: .center)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private func refreshDisplayedItems() {
        displayedItems = session.filteredItems(query: query)
        staticItemCount = session.staticItemCount(in: displayedItems, query: query)
    }

    private func shouldShowSnippetsSectionHeader(at index: Int) -> Bool {
        guard index < displayedItems.count else { return false }
        let item = displayedItems[index]
        guard item.sectionTitle == session.snippetsSectionTitle else { return false }
        if !hasQuery {
            return index == staticItemCount
        }
        if index == 0 { return true }
        return displayedItems[index - 1].sectionTitle != session.snippetsSectionTitle
    }

    private func resetSelection() {
        if let first = CommandPaletteRegistry.selectableIndices(in: displayedItems).first {
            selectedIndex = first
        } else {
            selectedIndex = 0
        }
    }

    private func moveSelection(by delta: Int) {
        guard let next = CommandPaletteRegistry.moveSelection(
            from: selectedIndex,
            direction: delta,
            in: displayedItems
        ) else { return }
        selectedIndex = next
    }

    private func executeSelected() {
        guard displayedItems.indices.contains(selectedIndex) else { return }
        let item = displayedItems[selectedIndex]
        guard item.isEnabled else { return }
        onExecute(item.id)
    }
}

private struct CommandPaletteRow: View {
    let item: CommandPaletteResolvedItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(item.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let shortcut = item.shortcutDisplay, !shortcut.isEmpty {
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(item.isEnabled ? Color.primary : Color.secondary.opacity(0.55))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(item.isEnabled ? 0.18 : 0.08))
            }
        }
        .contentShape(Rectangle())
    }
}

private struct CommandPaletteKeyboardMonitor: NSViewRepresentable {
    let isActive: Bool
    let onMoveSelection: (Int) -> Void
    let onExecute: () -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onMoveSelection: onMoveSelection,
            onExecute: onExecute,
            onDismiss: onDismiss
        )
    }

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.onMoveSelection = onMoveSelection
        context.coordinator.onExecute = onExecute
        context.coordinator.onDismiss = onDismiss
        nsView.syncMonitor()
    }

    final class MonitorView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            syncMonitor()
        }

        func syncMonitor() {
            coordinator?.syncMonitor(active: window != nil)
        }
    }

    final class Coordinator {
        var isActive: Bool
        var onMoveSelection: (Int) -> Void
        var onExecute: () -> Void
        var onDismiss: () -> Void
        private var monitor: Any?

        init(
            onMoveSelection: @escaping (Int) -> Void,
            onExecute: @escaping () -> Void,
            onDismiss: @escaping () -> Void
        ) {
            self.isActive = false
            self.onMoveSelection = onMoveSelection
            self.onExecute = onExecute
            self.onDismiss = onDismiss
        }

        func syncMonitor(active: Bool) {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard active, isActive else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard isActive else { return event }

            switch event.keyCode {
            case 53:
                onDismiss()
                return nil
            case 36, 76:
                onExecute()
                return nil
            case 125:
                onMoveSelection(1)
                return nil
            case 126:
                onMoveSelection(-1)
                return nil
            default:
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
