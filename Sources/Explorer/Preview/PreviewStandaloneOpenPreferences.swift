import CoreGraphics
import Foundation
import FileList

@MainActor
enum PreviewStandaloneOpenPreferences {
    static func options(for file: FileItem, allowsDockBack: Bool = false) -> PreviewStandaloneOpenOptions {
        let route = previewLoadRoute(for: file)
        var options = options(for: route, allowsDockBack: allowsDockBack)
        guard !options.fitImageToScreen else { return options }
        let kind = PreviewDetachedWindowContentKind.from(route: route)
        if let saved = PreviewDetachedWindowFrameStore.savedContentSize(for: kind) {
            options = PreviewStandaloneOpenOptions(
                allowsDockBack: options.allowsDockBack,
                fitImageToScreen: options.fitImageToScreen,
                initialWindowSize: saved
            )
        }
        return options
    }

    static func previewLoadRoute(for file: FileItem) -> PreviewLoadRoute {
        resolveRoute(for: file)
    }

    static func options(for route: PreviewLoadRoute, allowsDockBack: Bool = false) -> PreviewStandaloneOpenOptions {
        switch route {
        case .builtInImage, .builtInQuickLookImage:
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: true,
                initialWindowSize: nil
            )
        case .builtInPDF:
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: false,
                initialWindowSize: CGSize(width: 800, height: 1000)
            )
        case .builtInText, .customOverride(.text), .customOverride(.markdown), .customOverride(.html),
             .epub, .eml, .font,
             .customSupplement(.text), .customSupplement(.markdown), .customSupplement(.html):
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: false,
                initialWindowSize: CGSize(width: 720, height: 900)
            )
        case .model3D:
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: false,
                initialWindowSize: CGSize(width: 960, height: 720)
            )
        case .builtInMedia, .customOverride(.media), .customSupplement(.media):
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: false,
                initialWindowSize: CGSize(width: 960, height: 540)
            )
        case .builtInOffice, .docx, .doc, .xlsx, .xls, .csv, .rtf,
             .customOverride(.quickLook), .customSupplement(.quickLook):
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: false,
                initialWindowSize: CGSize(width: 800, height: 600)
            )
        case .archive, .customOverride(.archive), .customSupplement(.archive):
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: false,
                initialWindowSize: CGSize(width: 640, height: 480)
            )
        case .customOverride(.image), .customSupplement(.image):
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: true,
                initialWindowSize: nil
            )
        case .customOverride(.pdf), .customSupplement(.pdf):
            return PreviewStandaloneOpenOptions(
                allowsDockBack: allowsDockBack,
                fitImageToScreen: false,
                initialWindowSize: CGSize(width: 800, height: 1000)
            )
        case .unavailable:
            return .externalDefault
        }
    }

    private static func resolveRoute(for file: FileItem) -> PreviewLoadRoute {
        let url = file.url
        let ext = url.pathExtension.lowercased()
        let store = CustomPreviewRuleStore.shared
        return PreviewLoadDispatch.resolve(
            PreviewLoadDispatchInput(
                pathExtension: ext,
                fileName: url.lastPathComponent,
                isHtmlFile: PreviewTypeClassifier.isHtmlFile(ext),
                htmlPreviewMode: .preview,
                overridingMode: store.overridingRule(for: ext)?.mode,
                supplementalMode: store.activeMode(for: ext)
            )
        )
    }
}
