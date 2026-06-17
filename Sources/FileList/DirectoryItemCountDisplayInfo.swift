import Foundation

/// 文件夹子项数量展示信息（缩略图右下角角标）。
public struct DirectoryItemCountDisplayInfo: Equatable, Sendable {
    public let count: Int
    public let text: String
    
    public init(count: Int, text: String) {
        self.count = count
        self.text = text
    }
    
    public static let unknown = DirectoryItemCountDisplayInfo(count: -1, text: "")
    
    public static func formatted(_ count: Int) -> DirectoryItemCountDisplayInfo {
        DirectoryItemCountDisplayInfo(count: count, text: Self.displayText(for: count))
    }
    
    private static func displayText(for count: Int) -> String {
        if count >= 10_000 {
            return "≥10k"
        }
        if count >= 1_000 {
            let thousands = Double(count) / 1_000.0
            if thousands >= 10 {
                return "≥\(Int(thousands.rounded()))k"
            }
            return String(format: "%.1fk", thousands).replacingOccurrences(of: ".0k", with: "k")
        }
        return "\(count)"
    }
}
