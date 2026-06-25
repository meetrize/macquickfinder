import AppKit
import SwiftUI

struct PreviewFocuslessIconButton: NSViewRepresentable {
    let systemImageName: String
    let accessibilityLabel: String
    var isActive: Bool = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PreviewFocuslessIconNSView()
        view.setAccessibilityLabel(accessibilityLabel)
        view.updateImage(
            systemImageName,
            accessibilityLabel: accessibilityLabel,
            isEnabled: isEnabled,
            isActive: isActive
        )
        view.onClick = isEnabled ? { context.coordinator.didTap() } : nil
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.action = action
        guard let iconView = nsView as? PreviewFocuslessIconNSView else { return }
        iconView.setAccessibilityLabel(accessibilityLabel)
        iconView.updateImage(
            systemImageName,
            accessibilityLabel: accessibilityLabel,
            isEnabled: isEnabled,
            isActive: isActive
        )
        iconView.onClick = isEnabled ? { context.coordinator.didTap() } : nil
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTap() {
            action()
        }
    }
}

private final class PreviewFocuslessIconNSView: NSView {
    private let imageView = NSImageView()
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        focusRingType = .none

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 18),
            heightAnchor.constraint(equalToConstant: 18),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateImage(
        _ systemImageName: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        isActive: Bool = false
    ) {
        imageView.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: accessibilityLabel)
        if !isEnabled {
            imageView.contentTintColor = .disabledControlTextColor
            alphaValue = 0.6
        } else {
            imageView.contentTintColor = isActive ? .controlAccentColor : .labelColor
            alphaValue = 1
        }
    }

    @objc private func handleClick() {
        onClick?()
    }

    override var acceptsFirstResponder: Bool { false }
    override var canBecomeKeyView: Bool { false }
}
