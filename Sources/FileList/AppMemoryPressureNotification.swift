import Foundation

extension Notification.Name {
    /// Explorer 在系统内存压力时广播；FileList 等模块可监听并清理可重建缓存。
    public static let meoFindMemoryPressure = Notification.Name("MeoFind.AppMemoryPressure")
}
