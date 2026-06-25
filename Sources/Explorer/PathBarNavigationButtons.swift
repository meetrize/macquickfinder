import SwiftUI

struct PathBarNavigationButtons: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    private let buttonSize: CGFloat = 28

    var body: some View {
        HStack(spacing: 2) {
            navigationButton(
                systemName: "chevron.left",
                isEnabled: canGoBack,
                tooltip: L10n.Pathbar.back,
                action: onBack
            )
            navigationButton(
                systemName: "chevron.right",
                isEnabled: canGoForward,
                tooltip: L10n.Pathbar.forward,
                action: onForward
            )
        }
    }

    @ViewBuilder
    private func navigationButton(
        systemName: String,
        isEnabled: Bool,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
        .instantHoverTooltip(tooltip)
    }
}
