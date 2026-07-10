import AppKit

/// 按文件扩展名返回缩略图格子内容区淡色底（P3 创意增强）。
public enum FileListThumbnailTypeTint {
    public static func backgroundColor(for row: FileListRow, isDark: Bool) -> NSColor? {
        guard !row.isDirectory, !row.isParentDirectoryEntry else { return nil }
        let ext = URL(fileURLWithPath: row.iconPath).pathExtension.lowercased()
        guard let category = category(for: ext) else { return nil }
        let alpha: CGFloat = isDark ? 0.22 : 0.14
        return category.color.withAlphaComponent(alpha)
    }
    
    private enum Category {
        case image
        case video
        case audio
        case document
        case archive
        case code
        
        var color: NSColor {
            switch self {
            case .image: return NSColor(red: 0.95, green: 0.62, blue: 0.28, alpha: 1)
            case .video: return NSColor(red: 0.35, green: 0.58, blue: 0.95, alpha: 1)
            case .audio: return NSColor(red: 0.62, green: 0.42, blue: 0.92, alpha: 1)
            case .document: return NSColor(red: 0.92, green: 0.38, blue: 0.38, alpha: 1)
            case .archive: return NSColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)
            case .code: return NSColor(red: 0.42, green: 0.72, blue: 0.55, alpha: 1)
            }
        }
    }
    
    private static func category(for ext: String) -> Category? {
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "svg", "eps", "epsf", "epsi", "raw", "cr2", "nef":
            return .image
        case "mov", "mp4", "m4v", "mkv", "avi", "wmv", "webm", "mpg", "mpeg":
            return .video
        case "mp3", "wav", "flac", "m4a", "aac", "ogg", "aiff", "wma":
            return .audio
        case "pdf", "doc", "docx", "pages", "rtf", "txt", "md", "xls", "xlsx", "numbers", "ppt", "pptx", "key":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso":
            return .archive
        case "swift", "py", "js", "ts", "jsx", "tsx", "java", "c", "cpp", "h", "hpp", "go", "rs", "rb", "php", "html", "css", "json", "yaml", "yml", "sh", "zsh":
            return .code
        default:
            return nil
        }
    }
}
