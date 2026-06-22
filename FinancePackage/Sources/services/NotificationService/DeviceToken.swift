import Foundation

public struct DeviceToken: Sendable, Codable {
    public let id: String
    public let createdAt: String
    public let userId: String?

    public init(tokenString: String, userId: String? = nil) {
        self.id = tokenString
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.userId = userId
    }

    public init(tokenString: String, createdAt: String, userId: String? = nil) {
        self.id = tokenString
        self.createdAt = createdAt
        self.userId = userId
    }

    public static func tokenString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
