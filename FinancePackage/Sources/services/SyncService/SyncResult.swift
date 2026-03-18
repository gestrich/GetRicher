import Foundation

public struct SyncResult: Sendable {
    public let inserted: Int
    public let updated: Int
    public let deleted: Int

    public init(inserted: Int, updated: Int, deleted: Int) {
        self.inserted = inserted
        self.updated = updated
        self.deleted = deleted
    }

    public var hasChanges: Bool {
        inserted > 0 || updated > 0 || deleted > 0
    }
}
