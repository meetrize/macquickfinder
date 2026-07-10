import Foundation

extension PanoramaExpandDepthPolicy {
    var displayName: String {
        switch self {
        case .automatic:
            return L10n.Panorama.expandDepthAutomatic
        case .depth2:
            return L10n.Panorama.expandDepth2
        case .depth5:
            return L10n.Panorama.expandDepth5
        case .unlimited:
            return L10n.Panorama.expandDepthUnlimited
        }
    }
}
