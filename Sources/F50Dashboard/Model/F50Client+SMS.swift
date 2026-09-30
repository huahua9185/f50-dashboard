import Foundation

extension F50Client {
    private var setEndpoint: URL {
        URL(string: "http://\(host)/goform/goform_set_cmd_process")!
    }

    // MARK: - 登录

    /// 登录设备。成功后会话 cookie 由 URLSession 自动维持。
    ///
    /// 注意设备只允许连续 5 次失败，随后锁定 300 秒，所以密码错误时
    /// **绝不能自动重试**，直接把结果交给界面。
    func login(password: String) async -> LoginResult {
        guard !password.isEmpty else { return .failed("未设置密码") }

        do {
            let nonce = try await fetch(commands: ["LD"])["LD"]?.stringValue ?? ""
            guard !nonce.isEmpty else { return .failed("设备没有返回登录随机数") }

            // 固件版本之间 SHA256 输出的大小写不一致，两种都试一次。
            for uppercase in [true, false] {
                let hash = F50Auth.loginHash(password: password, nonce: nonce, uppercase: uppercase)
                let result = try await post(["goformId": "LOGIN", "password": hash], signed: false)

                switch result["result"]?.stringValue {
                case "0", "4":
                    return .success
                case "5":
                    return .locked(seconds: try? await lockRemainingSeconds())
                case "2":
                    return .failed("已有其他用户登录该设备")
                default:
                    // 大写没过就换小写再试；两种都失败才算密码错。
                    if !uppercase {
                        return .wrongPassword(remainingAttempts: try? await remainingAttempts())
                    }
                }
            }
            return .wrongPassword(remainingAttempts: nil)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// 当前是否仍处于登录态。会话会过期，轮询时用它决定要不要重新登录。
    func isLoggedIn() async -> Bool {
        let value = try? await fetch(commands: ["loginfo"])["loginfo"]?.stringValue
        return value == "ok"
    }

    private func remainingAttempts() async throws -> Int? {
        try await fetch(commands: ["psw_fail_num_str"])["psw_fail_num_str"]?.intValue
    }

    private func lockRemainingSeconds() async throws -> Int? {
        try await fetch(commands: ["login_lock_time"])["login_lock_time"]?.intValue
    }

    // MARK: - 短信

    /// 读取短信。需要登录态，未登录时设备返回空列表。
    func messages(limit: Int = 200) async throws -> [Message] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "isTest", value: "false"),
            URLQueryItem(name: "cmd", value: "sms_data_total"),
            URLQueryItem(name: "page", value: "0"),
            URLQueryItem(name: "data_per_page", value: String(limit)),
            // 1 = 设备本机存储；tags=10 表示不按已读/未读过滤，全部取回。
            URLQueryItem(name: "mem_store", value: "1"),
            URLQueryItem(name: "tags", value: "10"),
            URLQueryItem(name: "order_by", value: "order by id desc"),
            URLQueryItem(name: "_", value: String(Int(Date.now.timeIntervalSince1970 * 1000))),
        ]

        let payload = try await get(components.url!)

        return (payload["messages"] ?? .null).arrayValue.compactMap { entry in
            guard let id = entry["id"].intValue else { return nil }
            return Message(
                id: id,
                number: entry["number"].stringValue ?? "",
                body: MessageCoding.decode(entry["content"].stringValue ?? ""),
                date: MessageCoding.parseDate(entry["date"].stringValue),
                tag: MessageTag(raw: entry["tag"].intValue)
            )
        }
    }

    func unreadCount() async throws -> Int {
        try await fetch(commands: ["sms_unread_num"])["sms_unread_num"]?.intValue ?? 0
    }

    /// 把若干条短信标记为已读。
    @discardableResult
    func markRead(ids: [Int]) async throws -> Bool {
        guard !ids.isEmpty else { return true }
        let list = ids.map(String.init).joined(separator: ";") + ";"
        let result = try await post(["goformId": "SET_MSG_READ", "msg_id": list, "tag": "0"])
        return result["result"]?.stringValue == "success"
    }

    @discardableResult
    func deleteMessages(ids: [Int]) async throws -> Bool {
        guard !ids.isEmpty else { return true }
        let list = ids.map(String.init).joined(separator: ";") + ";"
        let result = try await post(["goformId": "DELETE_SMS", "msg_id": list])
        return result["result"]?.stringValue == "success"
    }

    // MARK: - 传输

    private func get(_ url: URL) async throws -> [String: JSONValue] {
        var request = URLRequest(url: url)
        request.setValue("http://\(host)/index.html", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        do {
            let (data, response) = try await F50Client.session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw F50ClientError.badResponse(http.statusCode)
            }
            return (try? JSONDecoder().decode([String: JSONValue].self, from: data)) ?? [:]
        } catch let error as URLError {
            throw F50ClientError.unreachable("连不上 \(host)（\(error.localizedDescription)）")
        }
    }

    /// 提交写操作。除登录外都要附带 AD 防重放字段。
    private func post(_ fields: [String: String], signed: Bool = true) async throws -> [String: JSONValue] {
        var body = fields
        body["isTest"] = "false"

        if signed, let digest = try? await accessDigest() {
            body["AD"] = digest
        }

        var request = URLRequest(url: setEndpoint)
        request.httpMethod = "POST"
        request.setValue("http://\(host)/index.html", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(formEncode(body).utf8)

        do {
            let (data, response) = try await F50Client.session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw F50ClientError.badResponse(http.statusCode)
            }
            return (try? JSONDecoder().decode([String: JSONValue].self, from: data)) ?? [:]
        } catch let error as URLError {
            throw F50ClientError.unreachable("连不上 \(host)（\(error.localizedDescription)）")
        }
    }

    /// AD = SHA256( SHA256(wa_inner_version + cr_version) + RD )
    private func accessDigest() async throws -> String? {
        let versions = try await fetch(commands: ["wa_inner_version", "cr_version"])
        guard let rd0 = versions["wa_inner_version"]?.stringValue,
              let rd1 = versions["cr_version"]?.stringValue,
              let nonce = try await fetch(commands: ["RD"])["RD"]?.stringValue
        else { return nil }

        return F50Auth.accessDigest(rd0: rd0, rd1: rd1, nonce: nonce, uppercase: true)
    }

    private func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields.map { key, value in
            let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encoded)"
        }.joined(separator: "&")
    }
}
