import SwiftUI
import AppKit

struct OperationRecordingReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var steps: [RecordedOperationStep]
    @State private var generalizePaths: Bool
    @State private var editedScript: String
    @State private var isScriptManuallyEdited = false
    @State private var validationResult: RecordedScriptValidationResult?
    @State private var snippetDraft: SnippetRecordingDraft?
    @State private var isSnippetEditorPresented = false

    let recordingCWD: String
    let recordedAt: Date
    let isInTrash: Bool
    let onSaveSnippet: (Snippet) -> Void

    init(
        context: OperationRecordingReviewContext,
        onSaveSnippet: @escaping (Snippet) -> Void
    ) {
        let generalizePaths = UserDefaults.standard.object(
            forKey: AppPreferences.OperationRecording.generalizePaths
        ) as? Bool ?? true
        let initialScript = OperationShellTranslator.translate(
            steps: context.steps,
            options: OperationShellTranslationOptions(
                generalizePaths: generalizePaths,
                recordingCWD: context.recordingCWD
            )
        )

        _steps = State(initialValue: context.steps)
        _generalizePaths = State(initialValue: generalizePaths)
        _editedScript = State(initialValue: initialScript)
        recordingCWD = context.recordingCWD
        recordedAt = context.recordedAt
        isInTrash = context.isInTrash
        self.onSaveSnippet = onSaveSnippet
    }

    private var suggestedScope: SnippetScope {
        let operations = steps.filter(\.isIncluded).map(\.operation)
        return SnippetRecordingDraftBuilder.inferScope(from: operations, recordingCWD: recordingCWD)
    }

    private var generatedScript: String {
        OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(
                generalizePaths: generalizePaths,
                recordingCWD: recordingCWD
            )
        )
    }

    private var trimmedScript: String {
        editedScript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.OperationRecording.reviewTitle)
                .font(.headline)

            Text(L10n.OperationRecording.reviewSubtitle(stepCount, recordedAt: recordedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            stepList

            HStack(alignment: .center, spacing: 8) {
                Toggle(L10n.OperationRecording.generalizePaths, isOn: $generalizePaths)
                    .onChange(of: generalizePaths) { _ in
                        syncGeneratedScriptIfNeeded()
                        UserDefaults.standard.set(generalizePaths, forKey: AppPreferences.OperationRecording.generalizePaths)
                    }
                SnippetVariableHelpButton()
            }

            Text(L10n.OperationRecording.scopeSuggestion(
                SnippetRecordingDraftBuilder.scopeLabel(for: suggestedScope)
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text(L10n.OperationRecording.previewLabel)
                    .font(.subheadline)
                Spacer()
                Button(L10n.OperationRecording.testScript) {
                    runValidation()
                }
                .disabled(trimmedScript.isEmpty)
            }

            TextEditor(text: $editedScript)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140, maxHeight: 220)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .onChange(of: editedScript) { _ in
                    isScriptManuallyEdited = true
                    validationResult = nil
                }

            if let validationResult {
                RecordedScriptValidationResultView(result: validationResult)
            }

            if isInTrash {
                Text(L10n.OperationRecording.trashWarning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(L10n.Action.cancel) { dismiss() }
                Spacer()
                Button(L10n.OperationRecording.copyScript) {
                    copyScriptToPasteboard()
                }
                .disabled(trimmedScript.isEmpty)
                Button(L10n.OperationRecording.createSnippet) {
                    presentSnippetEditor()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedScript.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onChange(of: steps) { _ in
            syncGeneratedScriptIfNeeded()
        }
        .sheet(isPresented: $isSnippetEditorPresented) {
            if let snippetDraft {
                SnippetEditorSheet(
                    snippet: nil,
                    draft: snippetDraft,
                    onSave: { snippet in
                        onSaveSnippet(snippet)
                        isSnippetEditorPresented = false
                        dismiss()
                    }
                )
            }
        }
    }

    private var stepCount: Int {
        steps.filter(\.isIncluded).count
    }

    @ViewBuilder
    private var stepList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach($steps) { $step in
                    if shouldShowStep(step.operation) {
                        Toggle(isOn: $step.isIncluded) {
                            Text(RecordedOperationSummary.title(for: step.operation))
                                .font(.body)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 160)
    }

    private func shouldShowStep(_ operation: RecordedOperation) -> Bool {
        switch operation {
        case .copy, .cut:
            return false
        default:
            return true
        }
    }

    private func syncGeneratedScriptIfNeeded() {
        guard !isScriptManuallyEdited else { return }
        editedScript = generatedScript
        validationResult = nil
    }

    private func runValidation() {
        validationResult = RecordedScriptValidator.validate(
            content: editedScript,
            recordingCWD: recordingCWD
        )
    }

    private func copyScriptToPasteboard() {
        guard !trimmedScript.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(trimmedScript, forType: .string)
    }

    private func presentSnippetEditor() {
        snippetDraft = SnippetRecordingDraftBuilder.build(
            steps: steps,
            script: trimmedScript,
            recordingCWD: recordingCWD
        )
        isSnippetEditorPresented = true
    }
}
