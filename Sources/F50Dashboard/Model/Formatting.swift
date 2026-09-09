import Foundation

enum Format {
    /// 流量总量，例如 “37.98 GB”。
    static func bytes(_ value: Double) -> String {
        units(value, suffixes: ["B", "KB", "MB", "GB", "TB"])
    }

    /// 实时速率，例如 “2.4 MB/s”。
    static func rate(_ value: Double) -> String {
        units(value, suffixes: ["B", "KB", "MB", "GB"]) + "/s"
    }

    /// 菜单栏空间很窄，这里省掉单位里的 B，显示成 “2.4M”。
    static func compactRate(_ value: Double) -> String {
        let text = units(value, suffixes: ["B", "K", "M", "G"], compact: true)
        return text
    }

    private static func units(
        _ value: Double,
        suffixes: [String],
        compact: Bool = false
    ) -> String {
        var amount = max(value, 0)
        var index = 0
        while amount >= 1024, index < suffixes.count - 1 {
            amount /= 1024
            index += 1
        }
        // 数值越大小数位越少，避免宽度忽宽忽窄。
        let decimals = amount >= 100 || index == 0 ? 0 : (amount >= 10 ? 1 : 2)
        let number = String(format: "%.\(decimals)f", amount)
        return compact ? "\(number)\(suffixes[index])" : "\(number) \(suffixes[index])"
    }

    /// 在线时长，例如 “4 天 16 小时” 或 “23 分 10 秒”。
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60

        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        if minutes > 0 { return "\(minutes) 分 \(secs) 秒" }
        return "\(secs) 秒"
    }

    static func signalStrength(_ rsrp: Double?) -> String {
        guard let rsrp else { return "—" }
        return "\(Int(rsrp)) dBm"
    }
}
