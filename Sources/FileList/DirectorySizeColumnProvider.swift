import Foundation

/// 目录大小列异步回填令牌；仅 revision 变化时刷新 Size 列，不触发整表 SwiftUI 更新。
public struct DirectorySizeColumnProvider: Equatable {
    public let revision: UInt
    public let display: (String) -> DirectorySizeDisplayInfo
    
    public init(
        revision: UInt,
        display: @escaping (String) -> DirectorySizeDisplayInfo
    ) {
        self.revision = revision
        self.display = display
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.revision == rhs.revision
    }
}
