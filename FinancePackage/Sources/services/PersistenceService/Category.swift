import Foundation
import SwiftData

@Model
public final class Category {
    public var id: UUID
    public var name: String
    public var emoji: String?
    public var colorHex: String?
    public var createdAt: Date

    @Relationship(inverse: \Transaction.localCategory) public var transactions: [Transaction]
    @Relationship(inverse: \Vendor.category) public var vendors: [Vendor]

    public init(
        id: UUID = UUID(),
        name: String,
        emoji: String? = nil,
        colorHex: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.transactions = []
        self.vendors = []
    }
}
