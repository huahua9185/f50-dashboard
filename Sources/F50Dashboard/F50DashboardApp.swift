import SwiftUI

@main
struct F50DashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 菜单栏项和仪表盘窗口都由 AppDelegate 用 AppKit 管理，
        // 这里只需要一个不会自己弹出来的占位 scene。
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 平时只做菜单栏常驻，不占 Dock；打开仪表盘窗口时才切成常规 app。
        NSApp.setActivationPolicy(.accessory)

        let monitor = DeviceMonitor.shared
        monitor.start()

        let controller = StatusItemController(monitor: monitor)
        statusItemController = controller
        controller.logPlacement()

        // 排查用：F50_SHOW_DASHBOARD=1 启动时直接打开仪表盘窗口。
        if ProcessInfo.processInfo.environment["F50_SHOW_DASHBOARD"] == "1" {
            controller.showDashboard()
        }

        // 命令行配置开机自启：F50_LOGIN_ITEM=1 开启，=0 关闭。
        if let flag = ProcessInfo.processInfo.environment["F50_LOGIN_ITEM"] {
            do {
                try LoginItem.setEnabled(flag == "1")
                print("开机自启已设置为 \(LoginItem.isEnabled)")
            } catch {
                print("设置开机自启失败: \(error.localizedDescription)")
            }
            fflush(stdout)
        }
    }

    /// 仪表盘窗口关掉后回到纯菜单栏状态，不在 Dock 里留一个空壳。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSApp.setActivationPolicy(.accessory) }
        return true
    }
}
