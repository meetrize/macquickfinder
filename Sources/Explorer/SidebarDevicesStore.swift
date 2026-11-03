import AppKit
import Combine
import Foundation

/// 侧边栏「设备」列表的唯一数据源：监听系统卷的挂载 / 卸载 / 重命名，自动刷新列表。
@MainActor
final class SidebarDevicesStore: ObservableObject {
    static let shared = SidebarDevicesStore()

    @Published private(set) var devices: [SidebarVolume] = []

    private var hasStarted = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // NSWorkspace 的卷通知只发给 workspace 自己的 notificationCenter，
        // 订阅 NotificationCenter.default 收不到，外接盘插入后侧边栏不会更新。
        let center = NSWorkspace.shared.notificationCenter
        let volumeNotificationNames: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification,
            NSWorkspace.didWakeNotification
        ]
        for name in volumeNotificationNames {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleRefresh()
                }
            }
            workspaceObservers.append(observer)
        }

        ConnectServerCenter.shared.$devicesRefreshToken
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleRefresh()
                }
            }
            .store(in: &cancellables)

        reload()
    }

    func reload() {
        devices = SidebarVolumeLoader.load()
    }

    /// 新卷挂载后系统枚举可能有延迟，立即刷新并短延迟重试。
    func scheduleRefresh() {
        reload()
        for delay in [0.3, 1.0] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                Task { @MainActor in
                    self?.reload()
                }
            }
        }
    }
}
