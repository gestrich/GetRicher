import Foundation

public struct Category: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let emoji: String?
    public let colorHex: String?
    public let createdAt: Date

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
    }
}
