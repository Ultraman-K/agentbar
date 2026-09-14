import Foundation
import Security

enum DeepSeekCredentialStoreError: Error, Equatable {
    case keychain(OSStatus)
}

final class DeepSeekCredentialStore {
    private let service: String
    private let account: String

    init(service: String = "com.codex.quota-menu.deepseek", account: String = "default") {
        self.service = service
        self.account = account
    }

    func read() throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw DeepSeekCredentialStoreError.keychain(status)
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw DeepSeekCredentialStoreError.keychain(updateStatus)
        }
        var addQuery = query
        addQuery[kSecValueData] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw DeepSeekCredentialStoreError.keychain(addStatus)
        }
    }

    func remove() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeepSeekCredentialStoreError.keychain(status)
        }
    }
}
