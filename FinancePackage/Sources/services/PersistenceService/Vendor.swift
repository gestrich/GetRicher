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

    @Relationship(inverse: \TransferRule.vendor) public var transferRules: [TransferRule]

    public init(
        id: UUID = UUID(),
        name: String,
        filterText: String,
        imageData: Data? = nil,
        category: Category? = nil,
        accountId: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.filterText = filterText
        self.imageData = imageData
        self.category = category
        self.accountId = accountId
        self.createdAt = createdAt
        self.transferRules = []
    }
}
