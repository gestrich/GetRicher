import Foundation

public struct DeviceToken: Sendable, Codable {
    public let id: String
    public let environment: String
    public let createdAt: String

    public init(tokenString: String, environment: String) {
        self.id = tokenString
        self.environment = environment
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }

    public init(tokenString: String, environment: String, createdAt: String) {
        self.id = tokenString
        self.environment = environment
        self.createdAt = createdAt
    }

    public static func tokenString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
