import Foundation
import SwiftData

@Model
public final class TransferPattern {
    public var id: UUID
    public var name: String
    public var matchText: String
    public var sourceAccountId: Int
    public var targetAccountId: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        matchText: String,
        sourceAccountId: Int,
        targetAccountId: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.matchText = matchText
        self.sourceAccountId = sourceAccountId
        self.targetAccountId = targetAccountId
        self.createdAt = createdAt
    }
}
