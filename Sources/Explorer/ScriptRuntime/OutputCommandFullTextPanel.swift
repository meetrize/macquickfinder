import SwiftUI

/// 多行命令全文浮层，仅覆盖输出区，不遮挡底部命令栏与历史按钮。
struct OutputCommandFullTextPanel: View {
    @Binding var text: String
    var onClose: () -> Void
    var onRun: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.25)
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack {
                    Text(L10n.Snippets.Output.fullCommandTitle)
                        .font(.headline)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.Snippets.Output.collapseCommand)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OutputPanelStyle.commandFieldBackgroundColor)

                Divider()

                HStack {
                    Spacer()
                    Button(L10n.Snippets.Output.runCommand, action: onRun)
                        .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
            .padding(12)
        }
    }
}
