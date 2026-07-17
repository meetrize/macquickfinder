import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ToolbarCustomizationPanelView: View {
    @ObservedObject var store: ToolbarCustomizationStore
    let environment: ExplorerToolbarEnvironment

    private var paletteRefs: [ToolbarItemRef] {
        store.workingLayout.paletteItemRefs()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Toolbar.customizeHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ToolbarPaletteDropSurface(store: store) {
                HStack(spacing: ExplorerToolbarMetrics.iconSpacing) {
                    ForEach(paletteRefs) { ref in
                        paletteChip(ref)
                    }

                    Spacer(minLength: 8)

                    addOpenAppButton
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(minHeight: 40)

            HStack {
                Button(L10n.Toolbar.customizeReset) {
                    store.resetDraftToDefaults()
                }

                Spacer()

                Button(L10n.Toolbar.customizeCancel) {
                    ToolbarCustomizationWindowController.finish(committing: false)
                }

                Button(L10n.Toolbar.customizeDone) {
                    ToolbarCustomizationWindowController.finish(committing: true)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minWidth: 560)
        .onAppear {
            // 避免窗口打开时「＋」自动获得键盘焦点并显示蓝框
            DispatchQueue.main.async {
                ToolbarCustomizationWindowController.activeWindow?.makeFirstResponder(nil)
            }
        }
    }

    private var addOpenAppButton: some View {
        Button {
            ToolbarOpenAppEditorWindowController.present(
                store: store,
                parentWindow: ToolbarCustomizationWindowController.activeWindow
            )
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: ExplorerToolbarMetrics.iconHitSize, height: ExplorerToolbarMetrics.iconHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .focusable(false)
        .help(L10n.Toolbar.addOpenApp)
    }

    @ViewBuilder
    private func paletteChip(_ ref: ToolbarItemRef) -> some View {
        let entry = ToolbarVisibleEntry(id: ref.id, zone: .main, kind: ref.kind)
        ToolbarDraggableChip(
            itemID: ref.id,
            kind: ref.kind,
            source: .palette
        ) {
            ToolbarItemChipLabel(
                entry: entry,
                layout: store.workingLayout,
                environment: environment
            )
        }
        .help(paletteHelp(ref))
        .contextMenu {
            if let action = customOpenAppAction(for: ref) {
                Button(L10n.Toolbar.changeIcon) {
                    store.changeCustomOpenAppIcon(id: action.id)
                }
                if action.customIconPath != nil {
                    Button(L10n.Toolbar.resetIcon) {
                        store.clearCustomOpenAppIcon(id: action.id)
                    }
                }
                Button(L10n.Toolbar.openAppEdit) {
                    presentOpenAppEditor(action)
                }
                Button(L10n.Action.delete, role: .destructive) {
                    store.deleteCustomOpenApp(id: action.id)
                }
            }
            if let shortcut = customOpenShortcutAction(for: ref) {
                Button(L10n.Toolbar.changeIcon) {
                    store.changeCustomOpenShortcutIcon(id: shortcut.id)
                }
                if shortcut.customIconPath != nil {
                    Button(L10n.Toolbar.resetIcon) {
                        store.clearCustomOpenShortcutIcon(id: shortcut.id)
                    }
                }
                Button(L10n.Action.delete, role: .destructive) {
                    store.deleteCustomOpenShortcut(id: shortcut.id)
                }
            }
        }
    }

    private func customOpenAppAction(for ref: ToolbarItemRef) -> CustomOpenAppAction? {
        guard ref.kind == .openApp, let actionID = ref.customActionID else { return nil }
        return store.workingLayout.customOpenApps.first { $0.id == actionID }
    }

    private func customOpenShortcutAction(for ref: ToolbarItemRef) -> CustomOpenShortcutAction? {
        guard ref.kind == .openShortcut, let actionID = ref.customActionID else { return nil }
        return store.workingLayout.customOpenShortcuts.first { $0.id == actionID }
    }

    private func presentOpenAppEditor(_ action: CustomOpenAppAction) {
        ToolbarOpenAppEditorWindowController.present(
            store: store,
            parentWindow: ToolbarCustomizationWindowController.activeWindow,
            editingAction: action
        )
    }

    private func paletteHelp(_ ref: ToolbarItemRef) -> String {
        if ref.kind == .openApp,
           let actionID = ref.customActionID,
           let action = store.workingLayout.customOpenApps.first(where: { $0.id == actionID }) {
            return action.displayName
        }
        if ref.kind == .openShortcut,
           let actionID = ref.customActionID,
           let action = store.workingLayout.customOpenShortcuts.first(where: { $0.id == actionID }) {
            return action.displayName
        }
        if let builtin = ref.builtinID {
            return builtin.rawValue
        }
        return ref.id
    }
}

private struct ToolbarPaletteDropSurface<Content: View>: View {
    @ObservedObject var store: ToolbarCustomizationStore
    @ViewBuilder let content: () -> Content
    @State private var isTargeted = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )

            content()
        }
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.compactMap({ ToolbarDragPayload.fromPasteboardString($0) }).first else {
                return false
            }
            guard payload.source == .toolbar else { return false }
            store.moveToPalette(itemID: payload.itemID)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

struct CustomOpenAppEditorSheet: View {
    @ObservedObject var store: ToolbarCustomizationStore
    var editingAction: CustomOpenAppAction?
    var onFinish: () -> Void = {}

    @State private var displayName = ""
    @State private var applicationPath = ""
    @State private var useApplicationIcon = true
    @State private var selectionPolicy: OpenAppSelectionPolicy = .requireSelection

    private var isEditing: Bool { editingAction != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isEditing ? L10n.Toolbar.openAppEditTitle : L10n.Toolbar.openAppTitle)
                    .font(.title2.weight(.semibold))
                Text(L10n.Toolbar.openAppChoosePrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 18) {
                OpenAppLabeledField(label: L10n.Toolbar.openAppName) {
                    TextField("", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                OpenAppLabeledField(label: L10n.Toolbar.openAppChoosePrompt) {
                    applicationPickerRow
                }

                OpenAppLabeledField(label: L10n.Toolbar.openAppSelectionPolicy) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $selectionPolicy) {
                            Text(L10n.Toolbar.openAppSelectionRequire)
                                .tag(OpenAppSelectionPolicy.requireSelection)
                            Text(L10n.Toolbar.openAppSelectionOptional)
                                .tag(OpenAppSelectionPolicy.passSelectionIfAvailable)
                            Text(L10n.Toolbar.openAppSelectionCurrentFolder)
                                .tag(OpenAppSelectionPolicy.passCurrentDirectory)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()

                        Text(L10n.Toolbar.openAppSelectionPolicyHelp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle(L10n.Toolbar.openAppUseAppIcon, isOn: $useApplicationIcon)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(L10n.Action.cancel, action: close)
                Button(isEditing ? L10n.Toolbar.openAppSave : L10n.Toolbar.openAppAdd, action: saveAction)
                    .disabled(applicationPath.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 540)
        .onAppear(perform: populateFields)
    }

    private var applicationPickerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if applicationPath.isEmpty {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                        .overlay {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                } else {
                    ToolbarAppIconView(applicationPath: applicationPath, size: 40)
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(applicationDisplayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if applicationPath.isEmpty {
                    Text(L10n.Toolbar.openAppChoosePrompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(applicationPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            Button(L10n.Toolbar.openAppChoose, action: chooseApplication)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var applicationDisplayTitle: String {
        if !displayName.isEmpty {
            return displayName
        }
        if applicationPath.isEmpty {
            return L10n.Toolbar.openAppChoose
        }
        return URL(fileURLWithPath: applicationPath).deletingPathExtension().lastPathComponent
    }

    private func close() {
        onFinish()
    }

    private func populateFields() {
        guard let editingAction else { return }
        displayName = editingAction.displayName
        applicationPath = editingAction.applicationPath
        useApplicationIcon = editingAction.useApplicationIcon
        selectionPolicy = editingAction.selectionPolicy
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = L10n.Toolbar.openAppChoosePrompt
        panel.prompt = L10n.Toolbar.openAppChoose

        guard panel.runModal() == .OK, let url = panel.url else { return }
        applicationPath = url.path
        if displayName.isEmpty {
            displayName = url.deletingPathExtension().lastPathComponent
        }
    }

    private func saveAction() {
        let bundleID = Bundle(url: URL(fileURLWithPath: applicationPath))?.bundleIdentifier
        let resolvedName = displayName.isEmpty
            ? URL(fileURLWithPath: applicationPath).deletingPathExtension().lastPathComponent
            : displayName
        let action = CustomOpenAppAction(
            id: editingAction?.id ?? UUID(),
            displayName: resolvedName,
            applicationPath: applicationPath,
            bundleIdentifier: bundleID,
            useApplicationIcon: useApplicationIcon,
            selectionPolicy: selectionPolicy
        )
        store.addCustomOpenApp(action)
        close()
    }
}

private struct OpenAppLabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
