import CryptoKit
import Foundation

/// 登录与写操作的签名算法。
///
/// 全部照搬设备 Web 界面 js/util.js、js/service.js 里的实现：
///   登录：password = SHA256( SHA256(明文) + LD )        LD 由 cmd=LD 取的一次性值
///   写操作：AD    = SHA256( SHA256(rd0 + rd1) + RD )    rd0/rd1 是两个固件版本号
enum F50Auth {
    /// 固件里 SHA256 输出是十六进制串，但大小写在不同版本间不一致，
    /// 两种都生成，登录时依次尝试。
    static func sha256(_ input: String, uppercase: Bool) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: uppercase ? "%02X" : "%02x", $0) }.joined()
    }

    static func loginHash(password: String, nonce: String, uppercase: Bool) -> String {
        sha256(sha256(password, uppercase: uppercase) + nonce, uppercase: uppercase)
    }

    /// 写操作的防重放字段。rd0 = wa_inner_version，rd1 = cr_version。
    static func accessDigest(rd0: String, rd1: String, nonce: String, uppercase: Bool) -> String {
        sha256(sha256(rd0 + rd1, uppercase: uppercase) + nonce, uppercase: uppercase)
    }
}

enum LoginResult: Sendable, Equatable {
    case success
    case wrongPassword(remainingAttempts: Int?)
    case locked(seconds: Int?)
    case failed(String)

    var isSuccess: Bool { self == .success }

    var message: String {
        switch self {
        case .success:
            return "已登录"
        case .wrongPassword(let remaining):
            if let remaining {
                return "密码错误，还剩 \(remaining) 次机会"
            }
            return "密码错误"
        case .locked(let seconds):
            if let seconds {
                return "尝试次数过多，设备已锁定，请等待 \(seconds) 秒"
            }
            return "尝试次数过多，设备已锁定"
        case .failed(let reason):
            return reason
        }
    }
}
