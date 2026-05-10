#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation

public struct UserAccount: Sendable, Codable {
    public let username: String
    public let passwordHash: String
    public let createdAt: String

    public init(username: String, passwordHash: String) {
        self.username = username
        self.passwordHash = passwordHash
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }

    public init(username: String, passwordHash: String, createdAt: String) {
        self.username = username
        self.passwordHash = passwordHash
        self.createdAt = createdAt
    }

    public static func hashPassword(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
