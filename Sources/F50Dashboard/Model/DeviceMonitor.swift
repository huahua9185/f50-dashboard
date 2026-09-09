import Foundation
import Observation
import os

/// 速率走势图上的一个采样点。
struct RateSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let upload: Double
    let download: Double
}

/// 持续轮询设备并把结果发布给界面。
@MainActor
@Observable
final class DeviceMonitor {
    /// 菜单栏和仪表盘窗口共用同一份数据，轮询也只跑一份。
    static let shared = DeviceMonitor()

    /// 最近一次成功读取的数据。轮询失败时保留旧值，界面靠 isReachable 变灰而不是清空。
    private(set) var snapshot = DeviceSnapshot()
    private(set) var history: [RateSample] = []
    private(set) var isReachable = false
    private(set) var lastError: String?
    private(set) var lastUpdate: Date?

    /// 走势图保留的采样点数量：2 秒一个点，120 个点约等于最近 4 分钟。
    private static let historyLimit = 120
    private static let liveInterval: Duration = .seconds(2)
    /// 静态信息每 15 轮（约 30 秒）刷新一次就够了。
    private static let staticRefreshEveryNTicks = 15

    var client = F50Client()

    private var pollingTask: Task<Void, Never>?
    /// 用 `log stream --predicate 'subsystem == "local.majun.f50dashboard"'` 观察轮询情况。
    private let log = Logger(subsystem: "local.majun.f50dashboard", category: "monitor")

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                await self?.poll(tick: tick)
                tick += 1
                try? await Task.sleep(for: Self.liveInterval)
            }
        }
    }

    /// 载入演示数据并停止轮询，用于无设备预览和文档截图。
    func loadDemo() {
        stop()
        snapshot = DemoData.snapshot
        history = DemoData.history
        isReachable = true
        lastError = nil
        lastUpdate = .now
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// 手动触发一次立即刷新，不打断既有的轮询节奏。
    func refreshNow() {
        Task { await poll(tick: 0) }
    }

    private func poll(tick: Int) async {
        var working = snapshot
        do {
            try await client.loadLiveData(into: &working)
            // 首轮以及每隔约 30 秒补一次静态信息。
            if tick % Self.staticRefreshEveryNTicks == 0 {
                try? await client.loadStaticData(into: &working)
            }
            snapshot = working
            appendSample(from: working)
            isReachable = true
            lastError = nil
            lastUpdate = .now
            log.debug(
                "轮询成功 下行=\(working.downloadRate, privacy: .public) 上行=\(working.uploadRate, privacy: .public) 终端=\(working.stations.count, privacy: .public)"
            )
        } catch {
            isReachable = false
            lastError = error.localizedDescription
            log.error("轮询失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func appendSample(from snapshot: DeviceSnapshot) {
        history.append(
            RateSample(
                timestamp: snapshot.capturedAt,
                upload: snapshot.uploadRate,
                download: snapshot.downloadRate
            )
        )
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }

    /// 走势图纵轴上限：跟随最近的峰值，并留一个下限避免空闲时曲线乱跳。
    var chartUpperBound: Double {
        let peak = history.reduce(0.0) { max($0, max($1.upload, $1.download)) }
        return max(peak * 1.2, 64 * 1024)
    }
}
