import Foundation

/// Finder 等外部入口一次选中多张图片时的打开策略。
enum PreviewExternalMultiImageOpenStrategy: String, CaseIterable, Identifiable, Codable {
    case singleWindowWithStrip
    case oneWindowPerFile

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .singleWindowWithStrip:
            return L10n.Settings.Preview.ExternalMultiImage.singleWindowWithStrip
        case .oneWindowPerFile:
            return L10n.Settings.Preview.ExternalMultiImage.oneWindowPerFile
        }
    }

    static let defaultValue: PreviewExternalMultiImageOpenStrategy = .singleWindowWithStrip
}
