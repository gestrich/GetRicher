import Foundation
import Security

public protocol KeychainClientProtocol: Sendable {
    func saveAPIToken(_ token: String) throws
    func getAPIToken() -> String?
    func deleteAPIToken() throws
}

public struct KeychainClient: KeychainClientProtocol, Sendable {
    private let service: String
    private let apiTokenKey: String

    public init(service: String = "com.finance.app", apiTokenKey: String = "lunchmoney.apiToken") {
        self.service = service
        self.apiTokenKey = apiTokenKey
    }

    public func saveAPIToken(_ token: String) throws {
        let data = token.data(using: .utf8)!

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiTokenKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiTokenKey,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }

    public func getAPIToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    public func deleteAPIToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiTokenKey
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
