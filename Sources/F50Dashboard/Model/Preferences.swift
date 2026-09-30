import Foundation
import Observation

/// 速率的显示单位。
///
/// 路由器网页用 bit/s（和运营商标称的「千兆」「1Gbps」一致），
/// macOS 这边的习惯是 Byte/s（活动监视器、下载器都用它）。两者差 8 倍，
/// 不是谁算错了，所以做成可切换。
enum RateUnit: String, CaseIterable, Sendable {
    case bytes
    case bits

    var title: String {
        switch self {
        case .bytes: return "MB/s"
        case .bits: return "Mb/s"
        }
    }

    var explanation: String {
        switch self {
        case .bytes: return "字节每秒，和访达、活动监视器一致"
        case .bits: return "比特每秒，和路由器网页、运营商标称一致"
        }
    }

    /// bit/s 就是字节数乘 8。
    var multiplier: Double { self == .bits ? 8 : 1 }

    var suffixes: [String] {
        switch self {
        case .bytes: return ["B", "KB", "MB", "GB"]
        case .bits: return ["b", "Kb", "Mb", "Gb"]
        }
    }

    /// 菜单栏空间紧张，只留一个量级字母；比特模式多带一个 b 以免和字节混淆。
    var compactSuffixes: [String] {
        switch self {
        case .bytes: return ["B", "K", "M", "G"]
        case .bits: return ["b", "Kb", "Mb", "Gb"]
        }
    }
}

@MainActor
@Observable
final class Preferences {
    static let shared = Preferences()

    private static let rateUnitKey = "rateUnit"

    var rateUnit: RateUnit {
        didSet { UserDefaults.standard.set(rateUnit.rawValue, forKey: Self.rateUnitKey) }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.rateUnitKey)
        rateUnit = stored.flatMap(RateUnit.init(rawValue:)) ?? .bytes
    }
}
