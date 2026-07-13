import Foundation

extension PreviewSession {
    func revealContentSearchMatch(lineNumber: Int, query: String) {
        text.searchQuery = query
        text.contentSearchJumpLine = lineNumber
        text.contentSearchJumpToken &+= 1
    }
}
