import SwiftUI

struct DirectoryContentSearchFilterBar: View {
    @ObservedObject var session: DirectoryContentSearchSession
    @Binding var isExpanded: Bool

    @State private var includeText = ""
    @State private var excludeText = ""

    var body: some View {
        HStack(spacing: 10) {
            filterField(title: L10n.Search.filterInclude, text: $includeText, placeholder: L10n.Search.filterIncludePlaceholder)
            filterField(title: L10n.Search.filterExclude, text: $excludeText, placeholder: L10n.Search.filterExcludePlaceholder)

            ContentSearchFilterToggle(
                isOn: $session.filter.includesSubdirectories,
                onSymbol: "folder.fill",
                offSymbol: "folder",
                help: L10n.Search.filterSubdirectories
            )

            ContentSearchFilterToggle(
                isOn: $session.filter.caseSensitive,
                textLabel: "Aa",
                help: L10n.Search.filterCaseSensitive
            )

            Spacer(minLength: 4)

            Button(L10n.Search.filterReset) {
                session.filter = .default
                syncTextFieldsFromFilter()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncTextFieldsFromFilter()
        }
        .onChange(of: includeText) { _ in applyTextFieldsToFilter() }
        .onChange(of: excludeText) { _ in applyTextFieldsToFilter() }
        .onChange(of: session.filter.includePatterns) { _ in
            syncTextFieldsFromFilter()
        }
        .onChange(of: session.filter.excludePatterns) { _ in
            syncTextFieldsFromFilter()
        }
    }

    private func filterField(title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func syncTextFieldsFromFilter() {
        includeText = session.filter.includePatterns.joined(separator: " ")
        excludeText = session.filter.excludePatterns.joined(separator: " ")
    }

    private func applyTextFieldsToFilter() {
        session.filter.includePatterns = splitPatterns(includeText)
        session.filter.excludePatterns = splitPatterns(excludeText)
    }

    private func splitPatterns(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}

private struct ContentSearchFilterToggle: View {
    @Binding var isOn: Bool
    var onSymbol: String?
    var offSymbol: String?
    var textLabel: String?
    let help: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Group {
                if let textLabel {
                    Text(textLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                } else if let onSymbol, let offSymbol {
                    Image(systemName: isOn ? onSymbol : offSymbol)
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
