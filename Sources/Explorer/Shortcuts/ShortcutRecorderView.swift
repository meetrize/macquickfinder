import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var binding: ShortcutBinding
    @State private var isRecording = false

    var body: some View {
        ShortcutRecorderRepresentable(
            binding: $binding,
            isRecording: $isRecording
        )
        .frame(minWidth: 120, minHeight: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isRecording ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .help(isRecording ? L10n.Settings.Shortcuts.recordingHint : L10n.Settings.Shortcuts.clickToRecord)
    }
}

private struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var binding: ShortcutBinding
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onBindingChanged = { binding = $0 }
        view.onRecordingChanged = { isRecording = $0 }
        view.update(binding: binding, isRecording: isRecording)
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.update(binding: binding, isRecording: isRecording)
    }
}

@MainActor
final class ShortcutRecorderNSView: NSView {
    var onBindingChanged: ((ShortcutBinding) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var currentBinding: ShortcutBinding = .defaultGlobalToggle
    private var recording = false
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(binding: ShortcutBinding, isRecording: Bool) {
        currentBinding = binding
        if recording != isRecording {
            recording = isRecording
            syncMonitor()
        }
        refreshLabel()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        setRecording(!recording)
    }

    override func keyDown(with event: NSEvent) {
        guard recording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            setRecording(false)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isEmpty else { return }

        let newBinding = ShortcutBinding(keyCode: event.keyCode, modifiers: flags)
        currentBinding = newBinding
        onBindingChanged?(newBinding)
        setRecording(false)
    }

    override func flagsChanged(with event: NSEvent) {
        guard recording else {
            super.flagsChanged(with: event)
            return
        }
        refreshLabel(previewFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
    }

    override func resignFirstResponder() -> Bool {
        setRecording(false)
        return super.resignFirstResponder()
    }

    private func setRecording(_ value: Bool) {
        recording = value
        onRecordingChanged?(value)
        syncMonitor()
        refreshLabel()
    }

    private func syncMonitor() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        guard recording else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                self.keyDown(with: event)
                return nil
            }
            if event.type == .flagsChanged {
                self.flagsChanged(with: event)
                return nil
            }
            return event
        }
    }

    private func refreshLabel(previewFlags: NSEvent.ModifierFlags? = nil) {
        if recording {
            if let previewFlags, !previewFlags.isEmpty {
                label.stringValue = ShortcutBinding(keyCode: currentBinding.keyCode, modifiers: previewFlags).displayString
            } else {
                label.stringValue = L10n.Settings.Shortcuts.recordingPlaceholder
            }
            label.textColor = .controlAccentColor
            return
        }

        label.stringValue = currentBinding.displayString
        label.textColor = .labelColor
    }
}
