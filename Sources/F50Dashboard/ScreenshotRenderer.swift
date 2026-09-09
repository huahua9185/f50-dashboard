import AppKit
import SwiftUI

/// 把界面直接渲染成 PNG，用于生成文档截图。
///
/// 不走屏幕截图，所以不需要解锁屏幕，出来的图也没有桌面背景和其他窗口干扰。
/// 用法：F50_DEMO=1 F50_RENDER_SHOTS=<输出目录> 启动，渲染完自动退出。
@MainActor
enum ScreenshotRenderer {
    static func render(monitor: DeviceMonitor, into directory: String) {
        let url = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        write(
            DashboardView(monitor: monitor, scrollable: false)
                .frame(width: 940, height: 880),
            to: url.appendingPathComponent("dashboard.png")
        )

        write(
            MenuBarLabelView(snapshot: monitor.snapshot, isReachable: true)
                // 真实菜单栏用模板图像渲染成单色，这里用灰度模拟那个效果
                .grayscale(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(white: 0.96)),
            to: url.appendingPathComponent("menubar.png")
        )

        write(
            MenuPanelView(monitor: monitor, onOpenDashboard: {}, onQuit: {}, isPreview: true)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(.rect(cornerRadius: 10)),
            to: url.appendingPathComponent("panel.png")
        )
    }

    private static func write(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        // 2 倍图，在 README 里缩放显示时仍然清晰
        renderer.scale = url.lastPathComponent == "menubar.png" ? 6 : 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else {
            print("渲染失败: \(url.lastPathComponent)")
            return
        }

        try? data.write(to: url)
        print("已生成 \(url.lastPathComponent) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
    }
}
