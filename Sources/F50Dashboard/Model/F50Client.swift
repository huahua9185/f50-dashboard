import Foundation

enum F50ClientError: LocalizedError {
    case badResponse(Int)
    case unreachable(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "设备返回 HTTP \(code)"
        case .unreachable(let reason): return reason
        }
    }
}

/// F50 Pro 的 Web 管理页背后是一组 goform 接口，返回纯 JSON。
/// 这些读取接口无需登录，但必须带 Referer，否则设备会拒绝。
struct F50Client: Sendable {
    var host: String = "192.168.0.1"

    private var endpoint: URL {
        URL(string: "http://\(host)/goform/goform_get_cmd_process")!
    }

    /// 每 2 秒轮询一次的实时字段。
    private static let liveCommands = [
        "network_type", "network_provider", "ppp_status", "wan_ipaddr",
        "signalbar", "Z5g_rsrp", "lte_rsrp",
        "realtime_tx_thrpt", "realtime_rx_thrpt",
        "realtime_tx_bytes", "realtime_rx_bytes", "realtime_time",
        "monthly_tx_bytes", "monthly_rx_bytes",
        "station_list",
    ]

    /// 基本不变的字段，低频刷新即可。
    private static let staticCommands = [
        "SSID1", "wa_inner_version", "hardware_version", "mac_address", "msisdn",
    ]

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 6
        // 设备的数值变化很快，任何缓存都会让面板显示过期数据。
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()

    private func fetch(commands: [String]) async throws -> [String: JSONValue] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "isTest", value: "false"),
            URLQueryItem(name: "multi_data", value: "1"),
            URLQueryItem(name: "cmd", value: commands.joined(separator: ",")),
            // 顺带绕开设备端和中间层的任何缓存。
            URLQueryItem(name: "_", value: String(Int(Date.now.timeIntervalSince1970 * 1000))),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("http://\(host)/index.html", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        do {
            let (data, response) = try await Self.session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw F50ClientError.badResponse(http.statusCode)
            }
            return try JSONDecoder().decode([String: JSONValue].self, from: data)
        } catch let error as URLError {
            throw F50ClientError.unreachable("连不上 \(host)（\(error.localizedDescription)）")
        }
    }

    /// 拉取实时数据，写入传入快照的对应字段。
    func loadLiveData(into snapshot: inout DeviceSnapshot) async throws {
        let payload = try await fetch(commands: Self.liveCommands)

        snapshot.capturedAt = .now
        snapshot.networkType = payload["network_type"]?.stringValue
        snapshot.provider = payload["network_provider"]?.stringValue
        snapshot.connection = ConnectionState(pppStatus: payload["ppp_status"]?.stringValue)
        snapshot.wanIPAddress = payload["wan_ipaddr"]?.stringValue
        snapshot.signalBars = payload["signalbar"]?.intValue
        // 5G 和 LTE 各有一套 RSRP 字段，哪个有值用哪个。
        snapshot.rsrp = payload["Z5g_rsrp"]?.doubleValue ?? payload["lte_rsrp"]?.doubleValue

        snapshot.uploadRate = payload["realtime_tx_thrpt"]?.doubleValue ?? 0
        snapshot.downloadRate = payload["realtime_rx_thrpt"]?.doubleValue ?? 0
        snapshot.sessionUploadBytes = payload["realtime_tx_bytes"]?.doubleValue ?? 0
        snapshot.sessionDownloadBytes = payload["realtime_rx_bytes"]?.doubleValue ?? 0
        snapshot.sessionDuration = payload["realtime_time"]?.doubleValue ?? 0
        snapshot.monthlyUploadBytes = payload["monthly_tx_bytes"]?.doubleValue ?? 0
        snapshot.monthlyDownloadBytes = payload["monthly_rx_bytes"]?.doubleValue ?? 0

        snapshot.stations = (payload["station_list"] ?? .null).arrayValue.map { entry in
            Station(
                macAddress: entry["mac_addr"].stringValue ?? "",
                hostname: entry["hostname"].stringValue ?? "",
                ipAddress: entry["ip_addr"].stringValue ?? ""
            )
        }
    }

    /// 拉取固件、SSID 等低频信息。
    func loadStaticData(into snapshot: inout DeviceSnapshot) async throws {
        let payload = try await fetch(commands: Self.staticCommands)

        snapshot.ssid = payload["SSID1"]?.stringValue
        snapshot.firmwareVersion = payload["wa_inner_version"]?.stringValue
        snapshot.hardwareVersion = payload["hardware_version"]?.stringValue
        snapshot.macAddress = payload["mac_address"]?.stringValue
        // 请求 msisdn，设备回的 key 却是 sim_msisdn，两个都认。
        snapshot.phoneNumber = payload["msisdn"]?.stringValue ?? payload["sim_msisdn"]?.stringValue
    }
}
