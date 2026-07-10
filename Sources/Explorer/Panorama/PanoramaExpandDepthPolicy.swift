import Foundation

/// 子目录全景模式的展开深度策略。
enum PanoramaExpandDepthPolicy: String, CaseIterable, Codable, Sendable {
    case automatic
    case depth2
    case depth5
    case unlimited

    /// 自动策略下优先 I/O 的深度上限（含根的直接子级 depth=1）。
    var bootstrapPriorityMaxDepth: Int? {
        switch self {
        case .automatic:
            return 2
        case .depth2:
            return 2
        case .depth5:
            return 5
        case .unlimited:
            return nil
        }
    }
}
