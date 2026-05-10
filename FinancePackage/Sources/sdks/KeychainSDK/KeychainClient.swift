import Foundation
import Security

public protocol KeychainClientProtocol: Sendable {
    func saveAPIToken(_ token: String) throws
    func getAPIToken() -> String?
    func deleteAPIToken() throws
    func saveUsername(_ username: String) throws
    func getUsername() -> String?
    func deleteUsername() throws
    func savePassword(_ password: String) throws
    func getPassword() -> String?
    func deletePassword() throws
}

public struct KeychainClient: KeychainClientProtocol, Sendable {
    private let service: String
    private let apiTokenKey: String
    private let usernameKey = "account.username"
    private let passwordKey = "account.password"

    public init(service: String = "com.finance.app", apiTokenKey: String = "lunchmoney.apiToken") {
        self.service = service
        self.apiTokenKey = apiTokenKey
    }

    public func saveAPIToken(_ token: String) throws {
        try save(token, forKey: apiTokenKey)
    }

    public func getAPIToken() -> String? {
        get(forKey: apiTokenKey)
    }

    public func deleteAPIToken() throws {
        try delete(forKey: apiTokenKey)
    }

    public func saveUsername(_ username: String) throws {
        try save(username, forKey: usernameKey)
    }

    public func getUsername() -> String? {
        get(forKey: usernameKey)
    }

    public func deleteUsername() throws {
        try delete(forKey: usernameKey)
    }

    public func savePassword(_ password: String) throws {
        try save(password, forKey: passwordKey)
    }

    public func getPassword() -> String? {
        get(forKey: passwordKey)
    }

    public func deletePassword() throws {
        try delete(forKey: passwordKey)
    }

    private func save(_ value: String, forKey key: String) throws {
        let data = value.data(using: .utf8)!
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }

    private func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }
}

public enum KeychainError: Error, Sendable {
    case unableToStore
    case unableToDelete
}
