import AppKit
import SwiftUI

struct PreviewOpenWithMenuButton: NSViewRepresentable {
    let fileURL: URL
    let systemImageName: String
    let accessibilityLabel: String
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PreviewOpenWithMenuNSView()
        view.setAccessibilityLabel(accessibilityLabel)
        view.updateImage(
            systemImageName,
            accessibilityLabel: accessibilityLabel,
            isEnabled: isEnabled
        )
        view.onClick = isEnabled ? { [context] in
            Task { @MainActor in
                context.coordinator.presentMenu(from: view)
            }
        } : nil
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.fileURL = fileURL
        guard let iconView = nsView as? PreviewOpenWithMenuNSView else { return }
        iconView.setAccessibilityLabel(accessibilityLabel)
        iconView.updateImage(
            systemImageName,
            accessibilityLabel: accessibilityLabel,
            isEnabled: isEnabled
        )
        iconView.onClick = isEnabled ? { [context] in
            Task { @MainActor in
                context.coordinator.presentMenu(from: iconView)
            }
        } : nil
    }

    final class Coordinator: NSObject {
        var fileURL: URL

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        @MainActor
        func presentMenu(from view: NSView) {
            OpenWithMenuBuilder.presentMenu(
                fileURLs: [fileURL],
                primaryFileURL: fileURL,
                positioning: view,
                onOpenWithApplication: { [fileURL] appURL in
                    OpenWithMenuBuilder.open(fileURLs: [fileURL], withApplicationAt: appURL)
                },
                onChooseOther: { [fileURL] in
                    FileOperations.openWith(url: fileURL)
                }
            )
        }
    }
}

final class PreviewOpenWithMenuNSView: NSView {
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
        isEnabled: Bool
    ) {
        imageView.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: accessibilityLabel)
        if !isEnabled {
            imageView.contentTintColor = .disabledControlTextColor
            alphaValue = 0.6
        } else {
            imageView.contentTintColor = .labelColor
            alphaValue = 1
        }
    }

    @objc private func handleClick() {
        onClick?()
    }

    override var acceptsFirstResponder: Bool { false }
    override var canBecomeKeyView: Bool { false }
}
