import Foundation

/// 挂在路由器上的一台终端。
struct Station: Identifiable, Hashable, Sendable {
    var macAddress: String
    var hostname: String
    var ipAddress: String

    var id: String { macAddress }

    /// 设备没上报主机名时退回显示 IP，别让列表出现空行。
    var displayName: String {
        hostname.isEmpty ? ipAddress : hostname
    }
}

enum ConnectionState: Sendable {
    case connected
    case connecting
    case disconnected
    case unknown

    init(pppStatus: String?) {
        switch pppStatus {
        case let status? where status.contains("connected"): self = .connected
        case let status? where status.contains("connecting"): self = .connecting
        case let status? where status.contains("disconnected"): self = .disconnected
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .connected: return "已连接"
        case .connecting: return "连接中"
        case .disconnected: return "已断开"
        case .unknown: return "未知"
        }
    }
}

/// 一次轮询得到的设备全貌。
struct DeviceSnapshot: Sendable {
    var capturedAt: Date = .now

    // 连接
    var networkType: String?
    var provider: String?
    var connection: ConnectionState = .unknown
    var wanIPAddress: String?

    // 信号
    var signalBars: Int?
    var rsrp: Double?

    // 实时速率（字节 / 秒）
    var uploadRate: Double = 0
    var downloadRate: Double = 0

    // 本次连接会话
    var sessionUploadBytes: Double = 0
    var sessionDownloadBytes: Double = 0
    var sessionDuration: TimeInterval = 0

    // 月度累计
    var monthlyUploadBytes: Double = 0
    var monthlyDownloadBytes: Double = 0

    // 终端
    var stations: [Station] = []

    // 设备静态信息
    var ssid: String?
    var firmwareVersion: String?
    var hardwareVersion: String?
    var macAddress: String?
    var phoneNumber: String?

    var totalSessionBytes: Double { sessionUploadBytes + sessionDownloadBytes }
    var totalMonthlyBytes: Double { monthlyUploadBytes + monthlyDownloadBytes }

    /// RSRP 落到 0…1，用于信号强度条。-120 dBm 视为最差，-70 dBm 及以上视为最好。
    var signalQuality: Double? {
        guard let rsrp else { return nil }
        return min(max((rsrp + 120) / 50, 0), 1)
    }
}
