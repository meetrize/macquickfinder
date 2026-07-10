import Foundation

/// 供工具栏等 Explorer 外层组件访问当前窗口的全景控制器。
@MainActor
enum PanoramaTreeControllerBridge {
    private static weak var activeController: PanoramaTreeController?

    static func bind(_ controller: PanoramaTreeController?) {
        activeController = controller
    }

    static var controller: PanoramaTreeController? {
        activeController
    }
}
