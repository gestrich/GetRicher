import Foundation
import SwiftData

/// SwiftData model for a paydown `TransactionType`. `kindRaw` stores the `TransactionTypeKind`;
/// `payeePatterns` is stored as a `[String]`. `isTombstoned` (NOT `isDeleted` — reserved by
/// Core Data) is the soft-delete flag for last-write-wins sync.
@Model
public final class TransactionType {
    public var id: UUID
    public var name: String
    public var kindRaw: String
    public var fundingAccountId: Int?
    public var targetAccountId: Int
    public var payeePatterns: [String]
    public var priority: Int
    public var createdAt: Date
    public var updatedAt: Date = Date()
    public var isTombstoned: Bool = false

    public init(
        id: UUID = UUID(),
        name: String,
        kindRaw: String,
        fundingAccountId: Int? = nil,
        targetAccountId: Int,
        payeePatterns: [String] = [],
        priority: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isTombstoned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kindRaw
        self.fundingAccountId = fundingAccountId
        self.targetAccountId = targetAccountId
        self.payeePatterns = payeePatterns
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isTombstoned = isTombstoned
    }
}
