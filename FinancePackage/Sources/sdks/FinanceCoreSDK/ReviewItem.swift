import Foundation

public struct ReviewItem: Identifiable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case weeklySpending
        case spendingGoal
        case savingsGoal
        case funAccountBalance
        case autopay
        case lowBalance
    }

    public enum Status: String, Sendable, Codable {
        case pending
        case approved
        case dismissed
        case snoozed
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let summary: String
    public let status: Status
    public let createdAt: String
    public let resolvedAt: String?

    public init(
        id: String,
        kind: Kind,
        title: String,
        summary: String,
        status: Status = .pending,
        createdAt: String,
        resolvedAt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}
