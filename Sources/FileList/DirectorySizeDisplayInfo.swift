import Foundation

public struct DirectorySizeDisplayInfo: Equatable, Sendable {
    public let sortableSize: Int64
    public let text: String
    
    public init(sortableSize: Int64, text: String) {
        self.sortableSize = sortableSize
        self.text = text
    }
    
    public static let unknown = DirectorySizeDisplayInfo(sortableSize: -1, text: "--")
}
