import AppKit
import SwiftUI

struct PreviewBrowserStripView: View {
    @ObservedObject var context: PreviewBrowserContext
    @ObservedObject var session: PreviewSession
    @StateObject private var thumbnailLoader = PreviewBrowserStripThumbnailLoader()

    private var screenScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2.0
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: PreviewBrowserStripMetrics.cellSpacing) {
                        ForEach(Array(context.orderedItems.enumerated()), id: \.element.id) { index, item in
                            PreviewBrowserStripCell(
                                item: item,
                                image: thumbnailLoader.image(for: item.id),
                                distanceFromCenter: index - context.currentIndex,
                                isSelected: index == context.currentIndex,
                                onSelect: {
                                    if session.switchBrowseTarget(to: item) {
                                        session.scheduleBrowseContentPrefetch()
                                    }
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                }
                .frame(height: PreviewBrowserStripMetrics.stripHeight)
                .onAppear {
                    scrollToCurrentItem(using: proxy, animated: false)
                    refreshThumbnails()
                }
                .onChange(of: context.currentIndex) { _ in
                    scrollToCurrentItem(using: proxy, animated: true)
                    refreshThumbnails()
                }
                .onDisappear {
                    thumbnailLoader.shutdown()
                }
            }
        }
        .frame(height: PreviewBrowserStripMetrics.stripHeight)
    }

    private func horizontalPadding(for viewportWidth: CGFloat) -> CGFloat {
        max(0, (viewportWidth - PreviewBrowserStripMetrics.thumbnailSize) / 2)
    }

    private func scrollToCurrentItem(using proxy: ScrollViewProxy, animated: Bool) {
        let targetID = context.currentItem.id
        if animated {
            withAnimation(.easeInOut(duration: PreviewBrowserStripMetrics.scrollAnimationDuration)) {
                proxy.scrollTo(targetID, anchor: .center)
            }
        } else {
            proxy.scrollTo(targetID, anchor: .center)
        }
    }

    private func refreshThumbnails() {
        thumbnailLoader.updatePrefetchWindow(
            items: context.orderedItems,
            centerIndex: context.currentIndex,
            screenScale: screenScale
        )
    }
}
