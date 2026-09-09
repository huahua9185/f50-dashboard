import SwiftUI

struct DashboardView: View {
    var monitor: DeviceMonitor
    /// ImageRenderer 渲染不出 ScrollView 的内容，生成文档截图时关掉滚动直接平铺。
    var scrollable = true

    private var snapshot: DeviceSnapshot { monitor.snapshot }

    var body: some View {
        Group {
            if scrollable {
                ScrollView { content }
            } else {
                content
            }
        }
        .background(.background)
        .navigationTitle("F50 Pro 仪表盘")
        .frame(minWidth: 760, minHeight: 600)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
                header
                HStack(alignment: .top, spacing: 12) {
                    connectionCard
                    signalCard
                    throughputCard
                    sessionCard
                }
                chartCard
                HStack(alignment: .top, spacing: 12) {
                    stationsCard
                    VStack(spacing: 12) {
                        monthlyCard
                        deviceCard
                    }
                    .frame(width: 260)
                }
        }
        .padding(18)
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "wifi.router.fill")
                .font(.title)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("ZTE F50 Pro").font(.title2.weight(.semibold))
                Text(snapshot.ssid.map { "SSID \($0)" } ?? "随身 5G 路由器")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(monitor.isReachable ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.background.secondary, in: .capsule)
    }

    private var statusText: String {
        guard monitor.isReachable else { return monitor.lastError ?? "设备离线" }
        guard let lastUpdate = monitor.lastUpdate else { return "读取中" }
        return "更新于 " + lastUpdate.formatted(date: .omitted, time: .standard)
    }

    // MARK: - 卡片

    private var connectionCard: some View {
        StatCard(title: "连接", systemImage: "network", tint: .green) {
            Text(snapshot.networkType ?? "—")
                .font(.title.weight(.semibold))
            MetricRow(label: "运营商", value: snapshot.provider ?? "—")
            MetricRow(label: "状态", value: snapshot.connection.label)
            MetricRow(label: "WAN IP", value: snapshot.wanIPAddress ?? "—")
        }
    }

    private var signalCard: some View {
        StatCard(title: "信号", systemImage: "antenna.radiowaves.left.and.right", tint: .teal) {
            HStack(alignment: .bottom, spacing: 8) {
                Text(Format.signalStrength(snapshot.rsrp))
                    .font(.title.weight(.semibold))
                Spacer()
                SignalBarsView(bars: snapshot.signalBars, height: 22)
            }
            if let quality = snapshot.signalQuality {
                ProgressBar(value: quality, tint: quality > 0.5 ? .green : .orange)
            }
            MetricRow(label: "信号格数", value: snapshot.signalBars.map { "\($0) / 5" } ?? "—")
        }
    }

    private var throughputCard: some View {
        StatCard(title: "实时速率", systemImage: "speedometer", tint: .blue) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down").font(.caption).foregroundStyle(.blue)
                    Text(Format.rate(snapshot.downloadRate))
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up").font(.caption).foregroundStyle(.orange)
                    Text(Format.rate(snapshot.uploadRate))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sessionCard: some View {
        StatCard(title: "在线时长", systemImage: "clock.arrow.circlepath", tint: .purple) {
            Text(Format.duration(snapshot.sessionDuration))
                .font(.title3.weight(.semibold))
                .fixedSize()
            MetricRow(label: "接入终端", value: "\(snapshot.stations.count) 台")
            MetricRow(label: "本月合计", value: Format.bytes(snapshot.totalMonthlyBytes))
        }
    }

    private var chartCard: some View {
        StatCard(title: "速率走势（最近 4 分钟）", systemImage: "chart.xyaxis.line", tint: .blue) {
            HStack(spacing: 14) {
                ChartKey(color: .blue, label: "下行", value: Format.rate(snapshot.downloadRate))
                ChartKey(color: .orange, label: "上行", value: Format.rate(snapshot.uploadRate))
            }
            ThroughputChart(samples: monitor.history, upperBound: monitor.chartUpperBound)
                .frame(height: 170)
        }
    }

    private var stationsCard: some View {
        StatCard(title: "已连接终端（\(snapshot.stations.count)）", systemImage: "laptopcomputer.and.iphone", tint: .indigo) {
            if snapshot.stations.isEmpty {
                Text("暂无终端接入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.stations.enumerated()), id: \.element.id) { index, station in
                        if index > 0 { Divider() }
                        stationRow(station)
                    }
                }
            }
        }
    }

    private func stationRow(_ station: Station) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: station))
                .foregroundStyle(.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(station.displayName).font(.callout.weight(.medium))
                Text(station.macAddress)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(station.ipAddress)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
    }

    /// 主机名里常常带着设备型号，用它挑一个合适的图标。
    private func icon(for station: Station) -> String {
        let name = station.hostname.lowercased()
        if name.contains("iphone") { return "iphone" }
        if name.contains("ipad") { return "ipad" }
        if name.contains("mac") || name.contains("book") { return "laptopcomputer" }
        if name.contains("tv") { return "appletv" }
        return "display"
    }

    private var monthlyCard: some View {
        StatCard(title: "月度流量", systemImage: "calendar", tint: .pink) {
            Text(Format.bytes(snapshot.totalMonthlyBytes))
                .font(.title2.weight(.semibold))
            MetricRow(label: "下载", value: Format.bytes(snapshot.monthlyDownloadBytes))
            MetricRow(label: "上传", value: Format.bytes(snapshot.monthlyUploadBytes))
        }
    }

    private var deviceCard: some View {
        StatCard(title: "设备信息", systemImage: "info.circle", tint: .gray) {
            MetricRow(label: "固件", value: snapshot.firmwareVersion ?? "—")
            MetricRow(label: "硬件", value: snapshot.hardwareVersion ?? "—")
            MetricRow(label: "MAC", value: snapshot.macAddress ?? "—")
            MetricRow(label: "管理地址", value: monitor.client.host)
        }
    }
}
