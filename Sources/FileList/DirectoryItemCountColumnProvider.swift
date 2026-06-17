import Foundation

/// 文件夹子项数量异步回填令牌；仅 revision 变化时刷新角标。
public struct DirectoryItemCountColumnProvider: Equatable {
    public let revision: UInt
    public let display: (String) -> DirectoryItemCountDisplayInfo
    
    public init(
        revision: UInt,
        display: @escaping (String) -> DirectoryItemCountDisplayInfo
    ) {
        self.revision = revision
        self.display = display
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.revision == rhs.revision
    }
}
