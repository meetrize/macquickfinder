import Foundation

@MainActor
final class ConnectServerCenter: ObservableObject {
    static let shared = ConnectServerCenter()

    @Published private(set) var presentSheetToken: UInt = 0
    @Published private(set) var devicesRefreshToken: UInt = 0

    private init() {}

    func requestPresentSheet() {
        presentSheetToken &+= 1
    }

    /// 挂载完成后刷新侧边栏 Devices（立即 + 短延迟重试，等待系统卷出现在列表中）。
    func requestDevicesRefresh() {
        devicesRefreshToken &+= 1
        Task { @MainActor in
            for delayMilliseconds in [300, 800] {
                try? await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
                devicesRefreshToken &+= 1
            }
        }
    }
}
