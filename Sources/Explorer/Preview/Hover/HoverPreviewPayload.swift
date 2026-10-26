import AppKit
import Foundation

/// 悬停预览只读载荷（轻量，不含编辑/会话状态）。
enum HoverPreviewPayload {
    case image(NSImage)
    case text(String)
    case meta(HoverPreviewMeta)
    case placeholder

    var approximateByteCost: Int {
        switch self {
        case .image(let image):
            let size = image.size
            let scale = max(image.recommendedLayerContentsScale(0), 1)
            let pixels = Int(size.width * scale) * Int(size.height * scale)
            return max(pixels * 4, 1)
        case .text(let string):
            return max(string.utf8.count, 1)
        case .meta:
            return 512
        case .placeholder:
            return 64
        }
    }
}

struct HoverPreviewMeta: Equatable {
    let title: String
    let subtitle: String
    let detail: String?
}
