import FileList

extension PreviewSession {
    /// 当前预览内容是否支持标题栏内搜索（文本、Markdown、Office 富文本、表格文本模式、PDF）。
    func showsPreviewTextSearch(for item: FileItem) -> Bool {
        guard !isLoading, errorMessage == nil else { return false }

        let ext = item.url.pathExtension
        if PreviewTypeClassifier.isPDFFile(ext) {
            return content.pdfDocument != nil
        }
        if PreviewTypeClassifier.isSpreadsheetFile(ext) {
            return office.spreadsheetMode == .text && !content.textContent.isEmpty
        }
        if PreviewTypeClassifier.isWordDocumentFile(ext) {
            if office.wordDocumentMode == .text {
                return !content.textContent.isEmpty
            }
            return content.officeRichText != nil
        }
        if PreviewTypeClassifier.isOfficeFile(ext) {
            return content.officeRichText != nil
        }
        if PreviewTypeClassifier.isTextFile(ext) {
            if PreviewTypeClassifier.isHtmlFile(ext), text.htmlMode == .preview {
                return false
            }
            if PreviewTypeClassifier.isMarkdownFile(ext), text.markdownMode == .preview {
                return true
            }
            return !content.textContent.isEmpty
        }
        return false
    }
}
