import Foundation

public struct Vendor: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let filterText: String
    public let accountId: Int?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        filterText: String,
        accountId: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.filterText = filterText
        self.accountId = accountId
        self.createdAt = createdAt
    }
}
