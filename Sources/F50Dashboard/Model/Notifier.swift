import AppKit
import UserNotifications
import os

/// 新短信的系统通知。
///
/// 验证码短信会额外带一个「复制验证码」按钮，点一下就进剪贴板，
/// 不用再打开面板手抄。
/// 通知的分类与动作标识。放在类型外面，nonisolated 的回调才能直接读。
private enum NotifierIDs {
    static let messageCategory = "f50.message"
    static let copyCodeAction = "f50.copyCode"
    static let codeKey = "verificationCode"
}

@MainActor
final class Notifier: NSObject {
    static let shared = Notifier()

    private let log = Logger(subsystem: "local.majun.f50dashboard", category: "notifier")
    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false


    func start() {
        center.delegate = self

        let copyCode = UNNotificationAction(
            identifier: NotifierIDs.copyCodeAction,
            title: "复制验证码",
            options: []
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: NotifierIDs.messageCategory,
                actions: [copyCode],
                intentIdentifiers: [],
                options: []
            )
        ])

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                self?.isAuthorized = granted
                if let error {
                    self?.log.error("通知授权失败: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func notify(_ message: Message) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = message.number.isEmpty ? "新短信" : message.number
        content.body = message.body
        content.sound = .default

        if let code = message.verificationCode {
            content.categoryIdentifier = NotifierIDs.messageCategory
            content.userInfo = [NotifierIDs.codeKey: code]
            // 副标题直接把验证码放大显示，很多时候扫一眼就够了。
            content.subtitle = "验证码 \(code)"
        }

        center.add(
            UNNotificationRequest(
                identifier: "f50.message.\(message.id)",
                content: content,
                trigger: nil
            )
        )
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    /// app 在前台时也要弹，否则菜单栏 app 基本永远收不到提示。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == NotifierIDs.copyCodeAction,
              let code = response.notification.request.content.userInfo[NotifierIDs.codeKey] as? String
        else { return }

        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        }
    }
}
