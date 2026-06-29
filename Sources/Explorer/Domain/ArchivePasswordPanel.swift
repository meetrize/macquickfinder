import AppKit

@MainActor
enum ArchivePasswordPanel {
    static func prompt(archiveName: String) -> String? {
        let alert = NSAlert()
        alert.messageText = L10n.Archive.passwordTitle
        alert.informativeText = L10n.Archive.passwordMessage(archiveName)
        alert.alertStyle = .informational

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = L10n.Archive.passwordPlaceholder
        alert.accessoryView = field

        alert.addButton(withTitle: L10n.Action.ok)
        alert.addButton(withTitle: L10n.Action.cancel)
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }
}
