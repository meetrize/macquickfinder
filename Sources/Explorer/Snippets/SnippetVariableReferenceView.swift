import SwiftUI

struct SnippetVariableHelpButton: View {
    @State private var isReferencePresented = false

    var body: some View {
        Button {
            isReferencePresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Snippets.VariableHelp.showReference)
        .popover(isPresented: $isReferencePresented, arrowEdge: .bottom) {
            SnippetVariableReferencePopover(onDismiss: { isReferencePresented = false })
        }
    }
}

private struct SnippetVariableReferencePopover: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.OperationRecording.variablesTitle)
                .font(.headline)

            Table(SnippetVariableCatalog.all) {
                TableColumn(L10n.Snippets.VariableHelp.columnToken) { variable in
                    Text(variable.token)
                        .font(.system(.body, design: .monospaced))
                }
                .width(min: 56, ideal: 72, max: 88)

                TableColumn(L10n.Snippets.VariableHelp.columnDescription) { variable in
                    Text(variable.description)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))

            Text(L10n.OperationRecording.variablesFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(L10n.Action.ok, action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 500, height: 440)
    }
}
