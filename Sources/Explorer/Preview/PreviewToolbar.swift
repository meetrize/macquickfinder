import FileList
import SwiftUI

struct PreviewToolbarOverflowModel: Identifiable {
    let id: String
    let menuTitle: String
    let menuSystemImage: String
    var isDisabled: Bool
    let estimatedWidth: CGFloat
    let menuAction: () -> Void
    let content: AnyView
}

private struct PreviewToolbarItemWidthPreference: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { max($0, $1) })
    }
}

struct PreviewToolbarOverflowLayout: View {
    let spacing: CGFloat
    let items: [PreviewToolbarOverflowModel]

    @State private var measuredWidths: [String: CGFloat] = [:]

    private func itemWidth(_ item: PreviewToolbarOverflowModel) -> CGFloat {
        if let measured = measuredWidths[item.id], measured > 0 {
            return measured
        }
        return item.estimatedWidth
    }

    private func fittingCount(for availableWidth: CGFloat) -> Int {
        guard !items.isEmpty else { return 0 }

        let menuReserve: CGFloat = 24

        func countFit(budget: CGFloat) -> Int {
            guard budget > 0 else { return 0 }
            var used: CGFloat = 0
            var count = 0
            for item in items {
                let addition = (count == 0 ? 0 : spacing) + itemWidth(item)
                if used + addition <= budget + 0.5 {
                    used += addition
                    count += 1
                } else {
                    break
                }
            }
            return count
        }

        let fitAll = countFit(budget: availableWidth)
        if fitAll >= items.count {
            return items.count
        }

        let fitWithMenu = countFit(budget: max(0, availableWidth - menuReserve - spacing))
        if fitWithMenu > 0 {
            return fitWithMenu
        }

        return 0
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(0, proxy.size.width)
            let visibleCount = fittingCount(for: availableWidth)
            let hasOverflow = visibleCount < items.count

            HStack(spacing: spacing) {
                ForEach(Array(items.prefix(visibleCount))) { item in
                    item.content
                        .fixedSize()
                        .background(
                            GeometryReader { itemProxy in
                                Color.clear.preference(
                                    key: PreviewToolbarItemWidthPreference.self,
                                    value: [item.id: itemProxy.size.width]
                                )
                            }
                        )
                }

                if hasOverflow {
                    Menu {
                        ForEach(Array(items.dropFirst(visibleCount))) { item in
                            Button(action: item.menuAction) {
                                Label(item.menuTitle, systemImage: item.menuSystemImage)
                            }
                            .disabled(item.isDisabled)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .menuIndicator(.hidden)
                    .buttonStyle(.borderless)
                    .focusable(false)
                    .instantHoverTooltip(L10n.Preview.Toolbar.moreActions)
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .clipped()
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: PanelTopBarMetrics.contentHeight)
        .clipped()
        .onPreferenceChange(PreviewToolbarItemWidthPreference.self) { measuredWidths = $0 }
    }
}
