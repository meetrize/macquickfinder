import Foundation

/// 目录 listing 路径键统一：去尾部 `/`、标准化、解析符号链接，避免 `/tmp` 与 `/private/tmp` 对不上。
public enum DirectoryListingPathNormalization {
    public static func canonicalPath(_ path: String) -> String {
        guard !path.isEmpty else { return path }
        return URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }
}
