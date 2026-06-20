import SwiftUI

struct PreviewBrowserNavBar: View {
    @ObservedObject var context: PreviewBrowserContext
    @ObservedObject var session: PreviewSession

    var body: some View {
        HStack(spacing: 8) {
            Button {
                session.browsePrevious()
                session.scheduleBrowseContentPrefetch()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(context.currentIndex == 0)
            .help("上一个")

            Text(context.currentItem.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(context.positionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                session.browseNext()
                session.scheduleBrowseContentPrefetch()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(context.currentIndex + 1 >= context.count)
            .help("下一个")

            Button {
                session.isBrowserStripExpanded.toggle()
            } label: {
                Image(systemName: session.isBrowserStripExpanded ? "chevron.down" : "film")
            }
            .buttonStyle(.borderless)
            .help(session.isBrowserStripExpanded ? "收起胶片条" : "展开胶片条")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }
}
