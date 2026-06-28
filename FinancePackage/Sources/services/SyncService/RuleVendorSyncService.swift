import FinanceCoreSDK
import PersistenceService
import SwiftData

/// Reconciles the server's merged Vendors + TransferRules into the local SwiftData store.
/// Tombstones (isDeleted) are kept locally so future merges keep propagating the deletion.
/// Vendors are applied first so rules can resolve their vendor relationship by id.
public struct RuleVendorSyncService: Sendable {
    public init() {}

    @MainActor
    public func apply(
        vendors: [FinanceCoreSDK.Vendor],
        rules: [FinanceCoreSDK.TransferRule],
        context: ModelContext
    ) throws {
        // MARK: Vendors
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
                    id: v.id,
                    name: v.name,
                    filterText: v.filterText,
                    accountId: v.accountId,
                    createdAt: v.createdAt,
                    updatedAt: v.updatedAt,
                    isTombstoned: v.isDeleted
                )
                context.insert(local)
                vendorsById[v.id] = local
            }
        }

        // MARK: Rules
        let existingRules = try context.fetch(FetchDescriptor<PersistenceService.TransferRule>())
        var rulesById = Dictionary(existingRules.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for r in rules {
            let vendor = r.vendor.flatMap { vendorsById[$0.id] }
            if let local = rulesById[r.id] {
                local.name = r.name
                local.vendor = vendor
                local.sourceAccountId = r.sourceAccountId
                local.targetAccountId = r.targetAccountId
                local.priority = r.priority
                local.kindRaw = r.kind.rawValue
                local.createdAt = r.createdAt
                local.updatedAt = r.updatedAt
                local.isTombstoned = r.isDeleted
            } else {
                let local = PersistenceService.TransferRule(
                    id: r.id,
                    name: r.name,
                    vendor: vendor,
                    sourceAccountId: r.sourceAccountId,
                    targetAccountId: r.targetAccountId,
                    priority: r.priority,
                    kindRaw: r.kind.rawValue,
                    createdAt: r.createdAt,
                    updatedAt: r.updatedAt,
                    isTombstoned: r.isDeleted
                )
                context.insert(local)
                rulesById[r.id] = local
            }
        }

        try context.save()
    }
}
