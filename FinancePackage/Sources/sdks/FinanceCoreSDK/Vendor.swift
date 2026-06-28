import Foundation

public struct Vendor: Identifiable, Sendable, Codable, Hashable, LWWMergeable {
    public let id: UUID
    public let name: String
    public let filterText: String
    public let accountId: Int?
    public let createdAt: Date
    /// Last modification time, used for last-write-wins sync.
    public let updatedAt: Date
    /// Soft-delete tombstone so deletions propagate across devices/server.
    public let isDeleted: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        filterText: String,
        accountId: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.filterText = filterText
        self.accountId = accountId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, filterText, accountId, createdAt, updatedAt, isDeleted
    }

    // Custom decoding so vendors persisted before updatedAt/isDeleted existed still decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        filterText = try c.decode(String.self, forKey: .filterText)
        accountId = try c.decodeIfPresent(Int.self, forKey: .accountId)
        let created = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSinceReferenceDate: 0)
        createdAt = created
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? created
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}
