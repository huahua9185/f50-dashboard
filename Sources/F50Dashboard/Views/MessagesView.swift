import AppKit
import SwiftUI

struct MessagesView: View {
    var center: MessageCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if center.isLoggedIn {
                messageList
            } else {
                LoginCard(center: center)
            }
        }
    }

    private var messageList: some View {
        StatCard(
            title: "短信（\(center.messages.count) 条，\(center.unreadCount) 条未读）",
            systemImage: "message",
            tint: .green
        ) {
            if center.messages.isEmpty {
                Text("暂无短信")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                if center.unreadCount > 0 {
                    Button("全部标记为已读") {
                        Task { await center.markAllRead() }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                VStack(spacing: 0) {
                    ForEach(Array(center.messages.enumerated()), id: \.element.id) { index, message in
                        if index > 0 { Divider() }
                        MessageRow(message: message, center: center)
                    }
                }
            }
        }
    }
}

private struct MessageRow: View {
    var message: Message
    var center: MessageCenter
    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 未读用一个实心点标出来，比整行变色安静
            Circle()
                .fill(message.tag.isUnread ? Color.accentColor : .clear)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(message.number.isEmpty ? "未知号码" : message.number)
                        .font(.callout.weight(message.tag.isUnread ? .semibold : .medium))
                    if message.tag == .sent {
                        Text("已发送")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let date = message.date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(message.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let code = message.verificationCode {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        didCopy = true
                    } label: {
                        Label(didCopy ? "已复制 \(code)" : "复制验证码 \(code)",
                              systemImage: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .tint(.accentColor)
                }
            }

            Menu {
                if message.tag.isUnread {
                    Button("标记为已读") { Task { await center.markRead(message) } }
                }
                Button("复制正文") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.body, forType: .string)
                }
                Divider()
                Button("删除", role: .destructive) { Task { await center.delete(message) } }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20)
        }
        .padding(.vertical, 8)
    }
}

/// 未登录时显示的密码输入卡片。
private struct LoginCard: View {
    var center: MessageCenter
    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        StatCard(title: "短信", systemImage: "message", tint: .green) {
            Text("读取短信需要登录路由器")
                .font(.callout.weight(.medium))

            Text("密码就是你打开 \(center.client.host) 管理页时用的那个。只保存在本机钥匙串里。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                SecureField("管理密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit(submit)

                Button(isWorking ? "登录中…" : "登录", action: submit)
                    .disabled(password.isEmpty || isWorking)
            }

            if let status = center.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(center.isBlocked ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if center.isBlocked {
                // 设备只给 5 次机会，错了就必须停下来等用户确认，不能自动重试
                Text("已停止自动重试，避免设备被锁定。确认密码后重新登录。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        isWorking = true
        Task {
            await center.updatePassword(password)
            isWorking = false
            if center.isLoggedIn { password = "" }
        }
    }
}
