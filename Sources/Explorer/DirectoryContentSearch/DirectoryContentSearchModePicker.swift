import SwiftUI

struct DirectoryContentSearchModePicker: View {
    @Binding var selection: DirectorySearchMode

    var body: some View {
        Menu {
            ForEach(DirectorySearchMode.allCases) { mode in
                Button(modeLabel(mode)) {
                    selection = mode
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(modeLabel(selection))
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func modeLabel(_ mode: DirectorySearchMode) -> String {
        switch mode {
        case .filename:
            return L10n.Search.modeFilename
        case .content:
            return L10n.Search.modeContent
        }
    }
}
