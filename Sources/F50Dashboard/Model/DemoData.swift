import Foundation

/// 演示用的假数据。
///
/// 用途有两个：一是没有 F50 Pro 的人也能看到界面长什么样，二是生成
/// 文档截图时不会把真实的 SSID、IP、MAC 和终端名暴露出去。
/// 启动时设 `F50_DEMO=1` 进入该模式，此时不会去连真实设备。
enum DemoData {
    static var snapshot: DeviceSnapshot {
        var snapshot = DeviceSnapshot()
        snapshot.networkType = "5G"
        snapshot.provider = "中国联通"
        snapshot.connection = .connected
        snapshot.wanIPAddress = "100.64.12.34"
        snapshot.signalBars = 5
        snapshot.rsrp = -85
        snapshot.uploadRate = 486_000
        snapshot.downloadRate = 3_260_000
        snapshot.sessionDuration = 4 * 86_400 + 16 * 3_600
        snapshot.monthlyDownloadBytes = 38_010_000_000
        snapshot.monthlyUploadBytes = 12_760_000_000
        snapshot.ssid = "F50Pro_5G"
        snapshot.firmwareVersion = "F50ProV1.0.0B25"
        snapshot.hardwareVersion = "F50ProHW1.0"
        snapshot.macAddress = "a4:83:e7:00:11:22"
        snapshot.stations = [
            Station(macAddress: "a4:83:e7:aa:bb:01", hostname: "MacBook-Pro", ipAddress: "192.168.0.101"),
            Station(macAddress: "a4:83:e7:aa:bb:02", hostname: "iPhone", ipAddress: "192.168.0.102"),
            Station(macAddress: "a4:83:e7:aa:bb:03", hostname: "iPad", ipAddress: "192.168.0.103"),
        ]
        return snapshot
    }

    /// 造一段起伏自然的速率历史，让走势图有东西可画。
    static var history: [RateSample] {
        let now = Date.now
        return (0..<120).map { index in
            let t = Double(index)
            // 两个周期叠加，做出忽高忽低但不规律的下载曲线
            let burst = max(sin(t / 9) * 0.6 + sin(t / 3.4) * 0.4, 0)
            let download = 220_000 + burst * burst * 4_200_000
            let upload = 90_000 + max(sin(t / 7 + 1.2), 0) * 620_000
            return RateSample(
                timestamp: now.addingTimeInterval(-Double(120 - index) * 2),
                upload: upload,
                download: download
            )
        }
    }
}
