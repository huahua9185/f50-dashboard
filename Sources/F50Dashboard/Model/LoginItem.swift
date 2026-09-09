import Foundation
import ServiceManagement
import os

/// 开机自启开关，走 macOS 13+ 的 SMAppService。
///
/// 注册后这个 app 会出现在「系统设置 › 通用 › 登录项」里，用户随时能在那边关掉。
@MainActor
enum LoginItem {
    private static let log = Logger(subsystem: "local.majun.f50dashboard", category: "loginitem")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 系统要求登录项指向的 app 位置稳定，放在 /Applications 之外注册容易失效。
    static var isInApplicationsFolder: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            log.info("已注册开机自启")
        } else {
            try SMAppService.mainApp.unregister()
            log.info("已取消开机自启")
        }
    }
}
