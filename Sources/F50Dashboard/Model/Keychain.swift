import Foundation
import Security

/// 路由器管理密码的存放处。
///
/// 只存在本机钥匙串里，不落盘到任何配置文件，也不会进仓库。
/// 用的是 app 自己的 keychain item，和系统登录钥匙串是两回事。
enum Keychain {
    private static let service = "local.majun.f50dashboard.router"

    /// 同一台 Mac 可能先后接过不同的设备，按 host 分开存。
    private static func query(host: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
        ]
    }

    static func password(for host: String) -> String? {
        var query = query(host: host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8),
              !password.isEmpty
        else { return nil }
        return password
    }

    @discardableResult
    static func setPassword(_ password: String, for host: String) -> Bool {
        let query = query(host: host)

        guard !password.isEmpty else {
            SecItemDelete(query as CFDictionary)
            return true
        }

        let data = Data(password.utf8)
        // 先试更新，条目不存在再新增。
        let updated = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updated == errSecSuccess { return true }

        var insert = query
        insert[kSecValueData as String] = data
        // 只在本机解锁后可读，不参与 iCloud 同步。
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    static func hasPassword(for host: String) -> Bool {
        password(for: host) != nil
    }
}
