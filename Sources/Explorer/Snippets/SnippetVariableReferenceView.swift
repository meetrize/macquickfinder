import SwiftUI

struct SnippetVariableReferenceView: View {
    let title: String
    let footer: String?

    init(title: String, footer: String? = nil) {
        self.title = title
        self.footer = footer
    }

    private let columns = [
        GridItem(.flexible(minimum: 72), spacing: 8, alignment: .leading),
        GridItem(.flexible(minimum: 72), spacing: 8, alignment: .leading),
        GridItem(.flexible(minimum: 72), spacing: 8, alignment: .leading),
        GridItem(.flexible(minimum: 72), spacing: 8, alignment: .leading),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(SnippetVariableCatalog.all) { variable in
                    SnippetVariableChipView(definition: variable)
                }
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SnippetVariableChipView: View {
    let definition: SnippetVariableDefinition

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(definition.token)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .offset(x: 4, y: -4)
        }
        .help(definition.description)
    }
}
