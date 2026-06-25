import Foundation

enum ImageZoomAction: Equatable {
    case fit
    case actualSize
}

enum ImagePreviewAction: Equatable {
    case save
}

enum TextPreviewAction: Equatable {
    case copyAll
    case scrollTop
    case scrollBottom
}

enum MediaControlAction: Equatable {
    case togglePlayPause
    case toggleMute
}

enum ArchivePreviewAction: Equatable {
    case copyList
}

enum PDFNavigationAction: Equatable {
    case previous
    case next
    case zoomIn
    case zoomOut
    case fitWidth
    case fitPage
    case goToPage(Int)
}

enum MarkdownDisplayMode: Equatable {
    case preview
    case source
}

enum HtmlDisplayMode: Equatable {
    case preview
    case source
}

enum SpreadsheetDisplayMode: Equatable {
    case text
    case quickLook
}
