import Foundation
import SwiftData

@Model
public final class Vendor {
    public var id: UUID
    public var name: String
    public var filterText: String
    public var imageData: Data?
    public var category: Category?
    public var accountId: Int?
    public var createdAt: Date
    /// Last modification time for last-write-wins sync.
    public var updatedAt: Date = Date()
    /// Soft-delete tombstone so deletions propagate to the server/other devices.
    public var isDeleted: Bool = false

    @Relationship(inverse: \TransferRule.vendor) public var transferRules: [TransferRule]

    public init(
        id: UUID = UUID(),
        name: String,
        filterText: String,
        imageData: Data? = nil,
        category: Category? = nil,
        accountId: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.filterText = filterText
        self.imageData = imageData
        self.category = category
        self.accountId = accountId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.transferRules = []
    }
}
