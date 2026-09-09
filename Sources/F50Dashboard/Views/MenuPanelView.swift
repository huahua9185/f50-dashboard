import SwiftUI

/// 点击菜单栏图标弹出的紧凑面板。
struct MenuPanelView: View {
    var monitor: DeviceMonitor
    /// 面板被塞在 NSPopover 里，拿不到 SwiftUI scene 的 openWindow，所以用回调。
    var onOpenDashboard: () -> Void
    var onQuit: () -> Void

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?

    private var snapshot: DeviceSnapshot { monitor.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if monitor.isReachable {
                liveSection
                Divider()
                summarySection
            } else {
                unreachableSection
            }

            Divider()
            settingsSection
            Divider()
            footer
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(monitor.isReachable ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text("ZTE F50 Pro").font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if monitor.isReachable {
                SignalBarsView(bars: snapshot.signalBars, height: 15)
            }
        }
        .padding(12)
    }

    private var subtitle: String {
        guard monitor.isReachable else { return "未连接" }
        let parts = [snapshot.provider, snapshot.networkType, snapshot.connection.label]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    private var liveSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                rateBlock(
                    title: "下行",
                    value: snapshot.downloadRate,
                    symbol: "arrow.down.circle.fill",
                    color: .blue
                )
                Divider().frame(height: 34)
                rateBlock(
                    title: "上行",
                    value: snapshot.uploadRate,
                    symbol: "arrow.up.circle.fill",
                    color: .orange
                )
            }

            ThroughputChart(
                samples: monitor.history,
                upperBound: monitor.chartUpperBound,
                showsAxes: false
            )
            .frame(height: 46)
        }
        .padding(12)
    }

    private func rateBlock(title: String, value: Double, symbol: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(color)
            Text(Format.rate(value))
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private var summarySection: some View {
        VStack(spacing: 7) {
            MetricRow(label: "信号强度", value: Format.signalStrength(snapshot.rsrp))
            MetricRow(label: "在线时长", value: Format.duration(snapshot.sessionDuration))
            MetricRow(label: "本月流量", value: Format.bytes(snapshot.totalMonthlyBytes))
            MetricRow(label: "连接终端", value: "\(snapshot.stations.count) 台")
        }
        .padding(12)
    }

    private var unreachableSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("读取不到设备").font(.callout.weight(.medium))
            Text(monitor.lastError ?? "请确认已连接 F50 Pro 的 Wi-Fi。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle("开机自启", isOn: $launchAtLogin)
                .font(.callout)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        try LoginItem.setEnabled(newValue)
                        loginItemError = nil
                    } catch {
                        // 注册失败就把开关拨回去，别让界面显示一个并未生效的状态
                        launchAtLogin = !newValue
                        loginItemError = error.localizedDescription
                    }
                }

            if let loginItemError {
                Text(loginItemError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !LoginItem.isInApplicationsFolder {
                Text("建议先把 app 移到「应用程序」文件夹，登录项才不会失效。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var footer: some View {
        HStack {
            Button("打开仪表盘", action: onOpenDashboard)

            Spacer()

            Button {
                monitor.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("立即刷新")

            Button {
                onQuit()
            } label: {
                Image(systemName: "power")
            }
            .help("退出")
        }
        .buttonStyle(.accessoryBar)
        .padding(10)
    }
}
