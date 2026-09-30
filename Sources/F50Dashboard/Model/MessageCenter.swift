import Foundation
import Observation
import os

/// 登录状态与短信收取。
@MainActor
@Observable
final class MessageCenter {
    static let shared = MessageCenter()

    private(set) var messages: [Message] = []
    private(set) var unreadCount = 0
    private(set) var isLoggedIn = false
    private(set) var status: String?
    /// 密码错误或设备锁定时置位，在用户改密码之前不再尝试登录。
    private(set) var isBlocked = false

    var client = F50Client()

    /// 短信不像速率那样需要秒级刷新，15 秒足够，也能少打扰设备。
    private static let interval: Duration = .seconds(15)

    private let log = Logger(subsystem: "local.majun.f50dashboard", category: "messages")
    private var pollingTask: Task<Void, Never>?
    /// 已经弹过通知的短信，避免重复提醒。
    private var notifiedIDs: Set<Int> = []
    private var hasLoadedOnce = false

    var hasPassword: Bool { Keychain.hasPassword(for: client.host) }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// 保存新密码并立刻重试登录。
    func updatePassword(_ password: String) async {
        Keychain.setPassword(password, for: client.host)
        isBlocked = false
        isLoggedIn = false
        status = nil
        notifiedIDs.removeAll()
        hasLoadedOnce = false
        await poll()
    }

    func refreshNow() {
        Task { await poll() }
    }

    private func poll() async {
        guard !isBlocked else { return }
        guard let password = Keychain.password(for: client.host) else {
            status = "未设置密码"
            isLoggedIn = false
            return
        }

        var sessionAlive = false
        if isLoggedIn {
            sessionAlive = await client.isLoggedIn()
        }
        if !sessionAlive {
            let result = await client.login(password: password)
            isLoggedIn = result.isSuccess
            status = result.isSuccess ? nil : result.message

            switch result {
            case .wrongPassword, .locked:
                // 继续重试只会耗尽剩余次数并把设备锁死，就此打住。
                isBlocked = true
                log.error("登录被拒，停止重试: \(result.message, privacy: .public)")
                return
            case .failed(let reason):
                log.error("登录失败: \(reason, privacy: .public)")
                return
            case .success:
                log.info("登录成功")
            }
        }

        do {
            unreadCount = try await client.unreadCount()
            let fetched = try await client.messages()
            let received = fetched.filter(\.tag.isReceived)

            // 首轮只建立基线，否则一启动就会把历史短信全部弹一遍。
            if hasLoadedOnce {
                for message in received where !notifiedIDs.contains(message.id) && message.tag.isUnread {
                    Notifier.shared.notify(message)
                }
            }
            notifiedIDs.formUnion(received.map(\.id))
            hasLoadedOnce = true

            messages = fetched
            status = nil
        } catch {
            status = error.localizedDescription
            log.error("读取短信失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    func markRead(_ message: Message) async {
        guard message.tag.isUnread else { return }
        _ = try? await client.markRead(ids: [message.id])
        await poll()
    }

    func markAllRead() async {
        let unread = messages.filter(\.tag.isUnread).map(\.id)
        guard !unread.isEmpty else { return }
        _ = try? await client.markRead(ids: unread)
        await poll()
    }

    func delete(_ message: Message) async {
        _ = try? await client.deleteMessages(ids: [message.id])
        notifiedIDs.remove(message.id)
        await poll()
    }
}
