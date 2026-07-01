import AppKit

@MainActor
final class OperationRecordingWindowCloseGuard: NSObject, NSWindowDelegate {
    private weak var recorder: OperationRecorder?
    private weak var attachedWindow: NSWindow?
    private var onStopAndGenerate: (([RecordedOperationStep], String) -> Void)?

    func attach(
        to window: NSWindow?,
        recorder: OperationRecorder,
        onStopAndGenerate: @escaping ([RecordedOperationStep], String) -> Void
    ) {
        if attachedWindow !== window {
            attachedWindow?.delegate = nil
            attachedWindow = window
            window?.delegate = self
        }
        self.recorder = recorder
        self.onStopAndGenerate = onStopAndGenerate
    }

    func detach() {
        attachedWindow?.delegate = nil
        attachedWindow = nil
        recorder = nil
        onStopAndGenerate = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let recorder, recorder.isRecording else { return true }

        let alert = NSAlert()
        alert.messageText = L10n.OperationRecording.closeWhileRecordingTitle
        alert.informativeText = L10n.OperationRecording.closeWhileRecordingMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.OperationRecording.closeStopAndGenerate)
        alert.addButton(withTitle: L10n.OperationRecording.closeDiscard)
        alert.addButton(withTitle: L10n.Action.cancel)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let cwd = recorder.recordingStartCWD ?? ""
            let steps = recorder.stop()
            onStopAndGenerate?(steps, cwd)
            return true
        case .alertSecondButtonReturn:
            recorder.discard()
            return true
        default:
            return false
        }
    }
}
