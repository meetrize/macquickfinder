import Foundation

/// 异步列回填令牌；仅 `revision` 变化时触发列刷新，避免整表 SwiftUI 更新。
public struct AsyncColumnProvider<Info: Equatable>: Equatable {
  public let revision: UInt
  public let display: (String) -> Info

  public init(
    revision: UInt,
    display: @escaping (String) -> Info
  ) {
    self.revision = revision
    self.display = display
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.revision == rhs.revision
  }
}

public typealias DirectorySizeColumnProvider = AsyncColumnProvider<DirectorySizeDisplayInfo>
public typealias DirectoryItemCountColumnProvider = AsyncColumnProvider<DirectoryItemCountDisplayInfo>
