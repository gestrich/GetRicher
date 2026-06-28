import Foundation
import SwiftData

@Model
public final class TransferRule {
    public var id: UUID
    public var name: String
    public var vendor: Vendor?
    public var sourceAccountId: Int?
    public var targetAccountId: Int
    public var priority: Int
    /// Raw `RuleKind` ("transfer" | "payment"); default enables lightweight SwiftData migration.
    public var kindRaw: String = "transfer"
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        vendor: Vendor? = nil,
        sourceAccountId: Int? = nil,
        targetAccountId: Int,
        priority: Int = 0,
        kindRaw: String = "transfer",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.sourceAccountId = sourceAccountId
        self.targetAccountId = targetAccountId
        self.priority = priority
        self.kindRaw = kindRaw
        self.createdAt = createdAt
    }
}
