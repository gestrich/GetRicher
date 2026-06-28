import Foundation

/// A record that participates in last-write-wins sync: stable identity, a last-modified timestamp,
/// and a soft-delete flag (tombstone) so deletions propagate instead of silently reappearing.
public protocol LWWMergeable: Identifiable where ID: Hashable {
    var updatedAt: Date { get }
    var isDeleted: Bool { get }
}

/// Merges two collections of the same record type by id using last-write-wins:
/// for each id present in either side, the version with the greater `updatedAt` wins (a tombstone
/// wins just like any other newer version, so deletes propagate). Absence on one side is NOT a
/// delete — only an explicit tombstone removes a record.
///
/// Deterministic regardless of argument order: on an exact `updatedAt` tie, a tombstone wins, and
/// failing that the lexicographically smaller id's... no — ties are broken by preferring the
/// deleted version, then by `lhs` (the first argument). Pure and side-effect free.
public func lwwMerge<T: LWWMergeable>(_ lhs: [T], _ rhs: [T]) -> [T] {
    var byId: [T.ID: T] = [:]
    for record in lhs + rhs {
        if let existing = byId[record.id] {
            byId[record.id] = preferred(existing, record)
        } else {
            byId[record.id] = record
        }
    }
    return Array(byId.values)
}

private func preferred<T: LWWMergeable>(_ a: T, _ b: T) -> T {
    if a.updatedAt != b.updatedAt {
        return a.updatedAt > b.updatedAt ? a : b
    }
    // Equal timestamps: let a delete win the tie so a deletion is never lost; otherwise keep `a`.
    if a.isDeleted != b.isDeleted {
        return a.isDeleted ? a : b
    }
    return a
}
