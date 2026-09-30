import Foundation

/// 一条短信。
struct Message: Identifiable, Sendable, Hashable {
    var id: Int
    var number: String
    var body: String
    var date: Date?
    var tag: MessageTag

    /// 短信里的验证码。
    ///
    /// 验证码短信几乎总是「4-8 位连续数字」，而且正文里通常只有这一串数字。
    /// 匹配到多个就放弃——与其给错，不如不给。
    var verificationCode: String? {
        // 先要求正文有验证码语境，否则订单号、年份都会误伤。
        let hints = ["验证码", "校验码", "动态码", "口令", "code", "Code", "CODE", "OTP"]
        guard hints.contains(where: { body.contains($0) }) else { return nil }

        // 取出所有独立的数字串，只有恰好一串 4-8 位时才敢断定是验证码。
        var runs: [String] = []
        var current = ""
        for character in body {
            if character.isNumber {
                current.append(character)
            } else {
                if !current.isEmpty { runs.append(current) }
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }

        let candidates = runs.filter { (4...8).contains($0.count) }
        return candidates.count == 1 ? candidates[0] : nil
    }
}

enum MessageTag: Int, Sendable {
    case unreadReceived = 0
    case readReceived = 1
    case sent = 2
    case draft = 3
    case sendFailed = 4
    case sending = 5
    case unknown = -1

    init(raw: Int?) {
        self = MessageTag(rawValue: raw ?? -1) ?? .unknown
    }

    var isReceived: Bool { self == .unreadReceived || self == .readReceived }
    var isUnread: Bool { self == .unreadReceived }
}

/// 短信正文和时间的编解码。
///
/// 这台设备（F50ProV1.0.0B25）的正文是 **Base64 编码的 UTF-8**，
/// 但 Web 界面的 js/util.js 里写的是 UTF-16BE 十六进制串——说明不同固件用法不同，
/// 所以解码时两种都认：先按 Base64 试，不成再按十六进制。
enum MessageCoding {
    static func decode(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        if let text = decodeBase64(raw) { return text }
        return decodeHex(raw)
    }

    private static func decodeBase64(_ raw: String) -> String? {
        guard let data = Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]),
              !data.isEmpty,
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty
        else { return nil }
        return text
    }

    private static func decodeHex(_ hex: String) -> String {
        var units: [UInt16] = []
        var index = hex.startIndex

        while index < hex.endIndex {
            let end = hex.index(index, offsetBy: 4, limitedBy: hex.endIndex) ?? hex.endIndex
            if let value = UInt16(hex[index..<end], radix: 16) {
                units.append(value)
            }
            index = end
        }

        return String(decoding: units, as: UTF16.self)
    }

    static func encode(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    /// 设备要求的时间格式：`YY;MM;DD;hh;mm;ss;+8`，末位是时区的小时偏移。
    static func timestamp(_ date: Date = .now, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let offsetHours = timeZone.secondsFromGMT(for: date) / 3600

        return String(
            format: "%02d;%02d;%02d;%02d;%02d;%02d;%+d",
            (c.year ?? 2000) % 100, c.month ?? 1, c.day ?? 1,
            c.hour ?? 0, c.minute ?? 0, c.second ?? 0, offsetHours
        )
    }

    /// 解析设备回传的时间。
    ///
    /// 实测是 `26,09,24,11,08,57,+0800`，但界面代码里也处理分号分隔的写法，
    /// 时区段则有 `+0800` 和 `+8` 两种，都要兼容。
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let separator: Character = raw.contains(",") ? "," : ";"
        let parts = raw.split(separator: separator).map { $0.trimmingCharacters(in: .whitespaces) }

        guard parts.count >= 6,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let hour = Int(parts[3]), let minute = Int(parts[4]), let second = Int(parts[5])
        else { return nil }

        var components = DateComponents()
        components.year = 2000 + year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        var calendar = Calendar(identifier: .gregorian)
        if parts.count >= 7, let zone = parseTimeZone(parts[6]) {
            calendar.timeZone = zone
        }
        return calendar.date(from: components)
    }

    /// `+0800` 当成时分，`+8` 当成整小时。
    private static func parseTimeZone(_ raw: String) -> TimeZone? {
        let sign = raw.hasPrefix("-") ? -1 : 1
        let digits = raw.filter(\.isNumber)
        guard let value = Int(digits) else { return nil }

        let seconds = digits.count >= 3
            ? (value / 100) * 3600 + (value % 100) * 60
            : value * 3600
        return TimeZone(secondsFromGMT: sign * seconds)
    }
}
