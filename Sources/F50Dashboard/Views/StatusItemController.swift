import AppKit
import Observation
import SwiftUI
import os

/// 自建菜单栏状态项。
///
/// 没有用 SwiftUI 的 MenuBarExtra：它的 label 只可靠支持 Text/Image，宽度不可控，
/// 而且拿不到状态项的实际位置，在菜单栏拥挤时无从诊断。
@MainActor
final class StatusItemController {
    private let monitor: DeviceMonitor
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let log = Logger(subsystem: "local.majun.f50dashboard", category: "statusitem")

    private var dashboardWindow: NSWindow?

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureButton()
        configurePopover()
        observeMonitor()
        updateButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.imagePosition = .imageOnly
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: MenuPanelView(
                monitor: monitor,
                onOpenDashboard: { [weak self] in self?.showDashboard() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    /// @Observable 的变更是一次性的，回调里要重新订阅才能持续收到通知。
    private func observeMonitor() {
        withObservationTracking {
            _ = monitor.snapshot.downloadRate
            _ = monitor.snapshot.uploadRate
            _ = monitor.snapshot.signalBars
            _ = monitor.isReachable
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateButton()
                self?.observeMonitor()
            }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }

        let renderer = ImageRenderer(
            content: MenuBarLabelView(snapshot: monitor.snapshot, isReachable: monitor.isReachable)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else { return }
        // 模板图像让系统按明暗菜单栏自动反色，省得自己适配主题。
        image.isTemplate = true
        button.image = image
        button.toolTip = tooltip
    }

    private var tooltip: String {
        guard monitor.isReachable else { return "F50 Pro · 未连接" }
        let parts = [monitor.snapshot.provider, monitor.snapshot.networkType].compactMap { $0 }
        return "F50 Pro · " + parts.joined(separator: " ")
            + "\n下行 \(Format.rate(monitor.snapshot.downloadRate))"
            + "\n上行 \(Format.rate(monitor.snapshot.uploadRate))"
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - 仪表盘窗口

    func showDashboard() {
        popover.performClose(nil)

        if dashboardWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "F50 Pro 仪表盘"
            window.contentViewController = NSHostingController(rootView: DashboardView(monitor: monitor))
            window.center()
            window.isReleasedWhenClosed = false
            dashboardWindow = window
        }

        // accessory 模式下的窗口拿不到焦点，先切成常规 app 再激活。
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }

    /// 把状态项的实际位置写进日志，菜单栏拥挤时用它判断是不是被挤到了刘海后面。
    func logPlacement() {
        let frame = statusItem.button?.window?.frame
        let screen = NSScreen.main?.frame
        log.info(
            "状态项 visible=\(self.statusItem.isVisible, privacy: .public) frame=\(String(describing: frame), privacy: .public) screen=\(String(describing: screen), privacy: .public)"
        )
    }
}
