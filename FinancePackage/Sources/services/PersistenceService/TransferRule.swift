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
    /// Last modification time for last-write-wins sync.
    public var updatedAt: Date = Date()
    /// Soft-delete tombstone so deletions propagate. NOTE: must NOT be named `isDeleted` —
    /// that collides with SwiftData/Core Data's reserved `isDeleted` and silently won't persist.
    public var isTombstoned: Bool = false

    public init(
        id: UUID = UUID(),
        name: String,
        vendor: Vendor? = nil,
        sourceAccountId: Int? = nil,
        targetAccountId: Int,
        priority: Int = 0,
        kindRaw: String = "transfer",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isTombstoned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.sourceAccountId = sourceAccountId
        self.targetAccountId = targetAccountId
        self.priority = priority
        self.kindRaw = kindRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isTombstoned = isTombstoned
    }
}
