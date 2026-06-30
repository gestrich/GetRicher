import FinanceCoreSDK
import PersistenceService
import SwiftData

/// Reconciles the server's merged Vendors + TransactionTypes into the local SwiftData store.
/// Tombstones (`isTombstoned`) are kept locally so future merges keep propagating the deletion.
public struct RuleVendorSyncService: Sendable {
    public init() {}

    @MainActor
    public func apply(
        vendors: [FinanceCoreSDK.Vendor],
        types: [FinanceCoreSDK.TransactionType],
        context: ModelContext
    ) throws {
        // MARK: Vendors (categorization / spending — separate from paydown)
        let existingVendors = try context.fetch(FetchDescriptor<PersistenceService.Vendor>())
        var vendorsById = Dictionary(existingVendors.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for v in vendors {
            if let local = vendorsById[v.id] {
                local.name = v.name
                local.filterText = v.filterText
                local.accountId = v.accountId
                local.createdAt = v.createdAt
                local.updatedAt = v.updatedAt
                local.isTombstoned = v.isDeleted
            } else {
                let local = PersistenceService.Vendor(
                    id: v.id, name: v.name, filterText: v.filterText, accountId: v.accountId,
                    createdAt: v.createdAt, updatedAt: v.updatedAt, isTombstoned: v.isDeleted
                )
                context.insert(local)
                vendorsById[v.id] = local
            }
        }

        // MARK: Transaction Types (paydown classification)
        let existingTypes = try context.fetch(FetchDescriptor<PersistenceService.TransactionType>())
        var typesById = Dictionary(existingTypes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for t in types {
            if let local = typesById[t.id] {
                local.name = t.name
                local.kindRaw = t.kind.rawValue
                local.fundingAccountId = t.fundingAccountId
                local.targetAccountId = t.targetAccountId
                local.payeePatterns = t.payeePatterns
                local.priority = t.priority
                local.createdAt = t.createdAt
                local.updatedAt = t.updatedAt
                local.isTombstoned = t.isDeleted
            } else {
                let local = PersistenceService.TransactionType(
                    id: t.id, name: t.name, kindRaw: t.kind.rawValue, fundingAccountId: t.fundingAccountId,
                    targetAccountId: t.targetAccountId, payeePatterns: t.payeePatterns, priority: t.priority,
                    createdAt: t.createdAt, updatedAt: t.updatedAt, isTombstoned: t.isDeleted
                )
                context.insert(local)
                typesById[t.id] = local
            }
        }

        try context.save()
    }
}
