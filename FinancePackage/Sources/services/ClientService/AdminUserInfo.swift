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

public struct BuildRun: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let status: String
    public let conclusion: String?
    public let createdAt: String
    public let htmlUrl: String
    public let commitMessage: String

    public init(id: Int, name: String, status: String, conclusion: String?, createdAt: String, htmlUrl: String, commitMessage: String) {
        self.id = id
        self.name = name
        self.status = status
        self.conclusion = conclusion
        self.createdAt = createdAt
        self.htmlUrl = htmlUrl
        self.commitMessage = commitMessage
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case createdAt, htmlUrl, commitMessage
    }
}

public struct BuildStatusResponse: Codable, Sendable {
    public let runs: [BuildRun]

    public init(runs: [BuildRun]) {
        self.runs = runs
    }
}
