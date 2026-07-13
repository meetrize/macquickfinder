import SwiftUI

struct DirectoryContentSearchToolbarSearch: View {
    @Binding var searchMode: DirectorySearchMode
    @Binding var searchText: String
    @Binding var contentQuery: String
    @Binding var activeBarField: BarTextFieldID?
    @Binding var isFilterExpanded: Bool

    private var activeQueryBinding: Binding<String> {
        Binding(
            get: { searchMode == .content ? contentQuery : searchText },
            set: { newValue in
                if searchMode == .content {
                    contentQuery = newValue
                } else {
                    searchText = newValue
                }
            }
        )
    }

    private var prompt: String {
        searchMode == .content ? L10n.Search.contentPrompt : L10n.Search.prompt
    }

    var body: some View {
        HStack(spacing: 4) {
            BarTextField(
                fieldID: .search,
                prompt: prompt,
                text: activeQueryBinding,
                activeField: $activeBarField,
                icon: "magnifyingglass",
                shape: .capsule,
                showsClearButton: true,
                clearTextOnEscape: true
            )

            DirectoryContentSearchModePicker(selection: $searchMode)

            if searchMode == .content {
                Button {
                    isFilterExpanded.toggle()
                } label: {
                    Image(systemName: isFilterExpanded ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.Search.filterTitle)
            }
        }
        .frame(width: 280)
    }
}
