import SwiftUI
import AppKit

struct OperationRecordingReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var steps: [RecordedOperationStep]
    @State private var generalizePaths: Bool
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
        _steps = State(initialValue: context.steps)
        _generalizePaths = State(
            initialValue: UserDefaults.standard.object(
                forKey: AppPreferences.OperationRecording.generalizePaths
            ) as? Bool ?? true
        )
        recordingCWD = context.recordingCWD
        recordedAt = context.recordedAt
        isInTrash = context.isInTrash
        self.onSaveSnippet = onSaveSnippet
    }

    private var suggestedScope: SnippetScope {
        let operations = steps.filter(\.isIncluded).map(\.operation)
        return SnippetRecordingDraftBuilder.inferScope(from: operations, recordingCWD: recordingCWD)
    }

    private var previewScript: String {
        OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(
                generalizePaths: generalizePaths,
                recordingCWD: recordingCWD
            )
        )
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
                    .onChange(of: generalizePaths) { newValue in
                        UserDefaults.standard.set(newValue, forKey: AppPreferences.OperationRecording.generalizePaths)
                    }
                SnippetVariableHelpButton()
            }

            Text(L10n.OperationRecording.scopeSuggestion(
                SnippetRecordingDraftBuilder.scopeLabel(for: suggestedScope)
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(L10n.OperationRecording.previewLabel)
                .font(.subheadline)

            ScrollView {
                Text(previewScript.isEmpty ? " " : previewScript)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(minHeight: 140, maxHeight: 220)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )

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
                .disabled(previewScript.isEmpty)
                Button(L10n.OperationRecording.createSnippet) {
                    presentSnippetEditor()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(previewScript.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
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

    private func copyScriptToPasteboard() {
        guard !previewScript.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(previewScript, forType: .string)
    }

    private func presentSnippetEditor() {
        snippetDraft = SnippetRecordingDraftBuilder.build(
            steps: steps,
            script: previewScript,
            recordingCWD: recordingCWD
        )
        isSnippetEditorPresented = true
    }
}
