import Foundation

enum ArchiveExtractMode: Equatable {
    /// 解压到归档所在目录（自动避让重名文件夹）。
    case here
    /// 解压到用户选择的目录。
    case destination(URL)
    /// 解压到「下载」文件夹。
    case downloads
}
