import Foundation

/// What a TransferRule does to the transactions it matches.
public enum RuleKind: String, Sendable, Codable, Hashable {
    /// Charges matched by this rule are funded by `sourceAccountId` — they roll up into that
    /// account's "owed" bucket for the period.
    case transfer
    /// Matched transactions are card payments (settlements), not spending — excluded from the
    /// paydown entirely (e.g. "THANK YOU FOR YOUR PMT").
    case payment
}

public struct TransferRule: Identifiable, Sendable, Codable, Hashable, LWWMergeable {
    public let id: UUID
    public let name: String
    public let vendor: Vendor?
    public let sourceAccountId: Int?
    public let targetAccountId: Int
    public let priority: Int
    public let kind: RuleKind
    public let createdAt: Date
    /// Last modification time, used for last-write-wins sync.
    public let updatedAt: Date
    /// Soft-delete tombstone so deletions propagate across devices/server.
    public let isDeleted: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        vendor: Vendor? = nil,
        sourceAccountId: Int? = nil,
        targetAccountId: Int,
        priority: Int = 0,
        kind: RuleKind = .transfer,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.sourceAccountId = sourceAccountId
        self.targetAccountId = targetAccountId
        self.priority = priority
        self.kind = kind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, vendor, sourceAccountId, targetAccountId, priority, kind, createdAt, updatedAt, isDeleted
    }

    // Custom decoding so rules persisted before kind/updatedAt/isDeleted existed still decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        vendor = try c.decodeIfPresent(Vendor.self, forKey: .vendor)
        sourceAccountId = try c.decodeIfPresent(Int.self, forKey: .sourceAccountId)
        targetAccountId = try c.decode(Int.self, forKey: .targetAccountId)
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        kind = try c.decodeIfPresent(RuleKind.self, forKey: .kind) ?? .transfer
        let created = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSinceReferenceDate: 0)
        createdAt = created
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? created
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}
