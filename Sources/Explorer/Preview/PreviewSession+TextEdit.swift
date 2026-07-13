import AppKit
import Foundation

enum PreviewTextEditStateLogic {
    static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func hasUnsavedChanges(liveContent: String, originalContent: String) -> Bool {
        normalized(liveContent) != normalized(originalContent)
    }
}

enum PreviewTextEditNavigationDecision: Equatable {
    case proceed
    case cancelled
}

enum PreviewTextEditNavigationPrompt {
    static func decision(for response: NSApplication.ModalResponse) -> PreviewTextEditNavigationDecision {
        switch response {
        case .alertFirstButtonReturn:
            return .proceed
        case .alertSecondButtonReturn:
            return .proceed
        case .alertThirdButtonReturn:
            return .cancelled
        default:
            return .cancelled
        }
    }

    static func shouldSaveBeforeProceeding(response: NSApplication.ModalResponse) -> Bool {
        response == .alertFirstButtonReturn
    }

    static func shouldDiscardBeforeProceeding(response: NSApplication.ModalResponse) -> Bool {
        response == .alertSecondButtonReturn
    }
}

extension PreviewSession {
    @discardableResult
    func browsePreviousIfAllowed() async -> Bool {
        guard await confirmDiscardTextEditsIfNeeded() else { return false }
        let handled = browsePrevious()
        if handled {
            scheduleBrowseContentPrefetch(
                settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
            )
        }
        return handled
    }

    @discardableResult
    func browseNextIfAllowed() async -> Bool {
        guard await confirmDiscardTextEditsIfNeeded() else { return false }
        let handled = browseNext()
        if handled {
            scheduleBrowseContentPrefetch(
                settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
            )
        }
        return handled
    }

    @discardableResult
    func switchBrowseTargetIfAllowed(to item: FileItem) async -> Bool {
        guard await confirmDiscardTextEditsIfNeeded() else { return false }
        guard switchBrowseTarget(to: item) else { return false }
        scheduleBrowseContentPrefetch(
            settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
        )
        return true
    }

    func syncTextEditStateAfterLoad() {
        text.originalContent = content.textContent
        text.liveEditContent = content.textContent
        text.hasUnsavedChanges = false
        text.displayMode = .viewing
    }

    func enterTextEditMode() {
        let item = browseTarget
        guard PreviewTextEditEligibility.canOfferEdit(file: item, session: self) else { return }

        let ext = item.url.pathExtension.lowercased()
        if PreviewTypeClassifier.isMarkdownFile(ext), text.markdownMode == .preview {
            text.markdownMode = .source
        }

        activateTextEditModeIfReady()
    }

    private func activateTextEditModeIfReady() {
        let item = browseTarget
        guard PreviewTextEditEligibility.canEdit(file: item, session: self) else { return }
        text.originalContent = content.textContent
        text.liveEditContent = content.textContent
        text.hasUnsavedChanges = false
        text.displayMode = .editing
    }

    func updateTextEditDirtyState(with liveContent: String) {
        guard text.isEditing else { return }
        text.liveEditContent = liveContent
        text.hasUnsavedChanges = PreviewTextEditStateLogic.hasUnsavedChanges(
            liveContent: liveContent,
            originalContent: text.originalContent
        )
    }

    func revertTextEdits(skipConfirm: Bool = false) async -> Bool {
        guard text.isEditing else { return true }
        guard text.hasUnsavedChanges else {
            applyTextEditRevert()
            return true
        }

        if !skipConfirm {
            let confirmed = await MainActor.run { () -> Bool in
                let alert = NSAlert()
                alert.messageText = L10n.Preview.TextEdit.discardConfirmTitle
                alert.informativeText = L10n.Preview.TextEdit.discardConfirmMessage(browseTarget.name)
                alert.alertStyle = .warning
                alert.addButton(withTitle: L10n.Preview.TextEdit.discardButton)
                alert.addButton(withTitle: L10n.Preview.TextEdit.cancelButton)
                return alert.runModal() == .alertFirstButtonReturn
            }
            guard confirmed else { return false }
        }

        applyTextEditRevert()
        return true
    }

    func saveEditedText() async -> Bool {
        guard text.isEditing else { return true }
        guard text.hasUnsavedChanges else {
            text.displayMode = .viewing
            return true
        }

        let item = browseTarget
        let textToSave = text.liveEditContent
        let itemID = item.id

        let saveResult: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
            do {
                try PreviewTextEditWriter.write(textToSave, to: item.url)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        guard browseTarget.id == itemID else { return false }

        switch saveResult {
        case .success:
            applyTextEditSaveSuccess(savedContent: textToSave, fileURL: item.url)
            return true
        case .failure(let error):
            content.textSaveErrorMessage = error.localizedDescription
            return false
        }
    }

    func confirmDiscardTextEditsIfNeeded() async -> Bool {
        guard text.isEditing, text.hasUnsavedChanges else { return true }

        let itemName = browseTarget.name
        let response = await MainActor.run { () -> NSApplication.ModalResponse in
            let alert = NSAlert()
            alert.messageText = L10n.Preview.TextEdit.unsavedTitle
            alert.informativeText = L10n.Preview.TextEdit.unsavedMessage(itemName)
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.Preview.TextEdit.saveButton)
            alert.addButton(withTitle: L10n.Preview.TextEdit.dontSaveButton)
            alert.addButton(withTitle: L10n.Preview.TextEdit.cancelButton)
            return alert.runModal()
        }

        switch PreviewTextEditNavigationPrompt.decision(for: response) {
        case .cancelled:
            return false
        case .proceed:
            if PreviewTextEditNavigationPrompt.shouldSaveBeforeProceeding(response: response) {
                return await saveEditedText()
            }
            if PreviewTextEditNavigationPrompt.shouldDiscardBeforeProceeding(response: response) {
                applyTextEditRevert()
                return true
            }
            return true
        }
    }

    private func applyTextEditRevert() {
        content.textContent = text.originalContent
        text.liveEditContent = text.originalContent
        text.hasUnsavedChanges = false
        text.displayMode = .viewing
    }

    private func applyTextEditSaveSuccess(savedContent: String, fileURL: URL) {
        content.textSaveErrorMessage = nil
        content.textContent = savedContent
        text.originalContent = savedContent
        text.liveEditContent = savedContent
        text.hasUnsavedChanges = false
        text.displayMode = .viewing
        browseContentPrefetcher.cancel()
        DirectoryListingItemRefreshCenter.notifyItemDidChange(at: fileURL)
        GitWorkingTreeRefreshCenter.notifyWorkingTreeMayHaveChanged(at: fileURL.path)
    }
}
