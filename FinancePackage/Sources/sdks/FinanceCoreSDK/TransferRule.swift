import Foundation

public struct TransferRule: Identifiable, Sendable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let vendor: Vendor?
    public let sourceAccountId: Int?
    public let targetAccountId: Int
    public let priority: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        vendor: Vendor? = nil,
        sourceAccountId: Int? = nil,
        targetAccountId: Int,
        priority: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.sourceAccountId = sourceAccountId
        self.targetAccountId = targetAccountId
        self.priority = priority
        self.createdAt = createdAt
    }
}
