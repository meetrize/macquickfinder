import FileList
import SwiftUI

extension PreviewSession {
    func showsEpubChapterPicker(for item: FileItem) -> Bool {
        guard !isLoading, errorMessage == nil else { return false }
        guard PreviewTypeClassifier.isEpubFile(item.url.pathExtension.lowercased()) else { return false }
        return content.epubPackage != nil
    }

    func previewEpubToolbarItems() -> [PreviewToolbarOverflowModel] {
        guard let package = content.epubPackage else { return [] }
        let chapterCount = package.chapters.count
        let currentIndex = min(max(epub.currentChapterIndex, 0), max(chapterCount - 1, 0))

        return [
            previewToolbarIconItem(
                id: "epub-prev",
                title: L10n.Preview.Toolbar.epubPreviousChapter,
                systemImage: "chevron.left",
                isDisabled: currentIndex <= 0,
                action: { [self] in epub.showPreviousChapter() }
            ),
            PreviewToolbarOverflowModel(
                id: "epub-progress",
                menuTitle: L10n.Preview.Epub.chapterProgress(currentIndex + 1, chapterCount),
                menuSystemImage: "book.pages",
                isDisabled: chapterCount == 0,
                estimatedWidth: 72,
                menuAction: {},
                content: AnyView(PreviewEpubChapterProgressLabel(session: self))
            ),
            previewToolbarIconItem(
                id: "epub-next",
                title: L10n.Preview.Toolbar.epubNextChapter,
                systemImage: "chevron.right",
                isDisabled: chapterCount == 0 || currentIndex >= chapterCount - 1,
                action: { [self] in epub.showNextChapter(chapterCount: chapterCount) }
            ),
        ]
    }
}
