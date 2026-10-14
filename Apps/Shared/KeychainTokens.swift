import Foundation
import Security
import MahiFinCore

struct KeychainTokens: TokenStore {
    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "MahiFin.authentication", kSecAttrAccount as String: account]
    }
    func read(account: String) throws -> String? {
        var value = query(account)
        value[kSecReturnData as String] = true
        value[kSecMatchLimit as String] = kSecMatchLimitOne
        var output: CFTypeRef?
        let status = SecItemCopyMatching(value as CFDictionary, &output)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = output as? Data, let token = String(data: data, encoding: .utf8) else { throw ClientError.storage }
        return token
    }
    func write(_ token: String, account: String) throws {
        let base = query(account)
        let data = Data(token.utf8)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var value = base
            value[kSecValueData as String] = data
            value[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(value as CFDictionary, nil) == errSecSuccess else { throw ClientError.storage }
        } else if status != errSecSuccess { throw ClientError.storage }
    }
    func remove(account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ClientError.storage }
    }
}
