import Foundation

public struct AdminUserInfo: Codable, Sendable {
    public let username: String
    public let createdAt: String
    public let hasLMToken: Bool

    public init(username: String, createdAt: String, hasLMToken: Bool) {
        self.username = username
        self.createdAt = createdAt
        self.hasLMToken = hasLMToken
    }
}

public struct AdminErrorsResponse: Codable, Sendable {
    public let errors: [String]
    public let message: String

    public init(errors: [String], message: String) {
        self.errors = errors
        self.message = message
    }
}
