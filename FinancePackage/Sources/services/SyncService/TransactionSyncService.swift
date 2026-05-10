import FinanceCoreSDK
import PersistenceService
import SwiftData

public struct TransactionSyncService: Sendable {

    public init() {}

    @MainActor
    public func sync(
        transactions: [FinanceCoreSDK.Transaction],
        context: ModelContext
    ) throws -> SyncResult {
        let fetchedIds = Set(transactions.map(\.lunchMoneyId))

        let descriptor = FetchDescriptor<PersistenceService.Transaction>()
        let existing = try context.fetch(descriptor)
        let existingByLMId = Dictionary(uniqueKeysWithValues: existing.compactMap { tx in
            (tx.lunchMoneyId, tx)
        })

        var inserted = 0
        var updated = 0

        for item in transactions {
            if let local = existingByLMId[item.lunchMoneyId] {
                if local.updatedAt != item.updatedAt {
                    apply(item, to: local, context: context)
                    updated += 1
                }
            } else {
                let local = makeTransaction(from: item, context: context)
                context.insert(local)
                inserted += 1
            }
        }

        var deleted = 0
        for local in existing {
            if !fetchedIds.contains(local.lunchMoneyId) {
                context.delete(local)
                deleted += 1
            }
        }

        try context.save()
        return SyncResult(inserted: inserted, updated: updated, deleted: deleted)
    }

    // MARK: - Private

    private func makeTransaction(from item: FinanceCoreSDK.Transaction, context: ModelContext) -> PersistenceService.Transaction {
        PersistenceService.Transaction(
            lunchMoneyId: item.lunchMoneyId,
            date: item.date,
            payee: item.payee,
            amount: item.amount,
            currency: item.currency,
            toBase: item.toBase,
            notes: item.notes,
            originalName: item.originalName,
            categoryId: item.categoryId,
            categoryName: item.categoryName,
            categoryGroupId: item.categoryGroupId,
            categoryGroupName: item.categoryGroupName,
            status: item.status,
            isIncome: item.isIncome,
            isPending: item.isPending,
            excludeFromBudget: item.excludeFromBudget,
            excludeFromTotals: item.excludeFromTotals,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            recurringId: item.recurringId,
            recurringPayee: item.recurringPayee,
            recurringDescription: item.recurringDescription,
            recurringCadence: item.recurringCadence,
            recurringGranularity: item.recurringGranularity,
            recurringQuantity: item.recurringQuantity,
            recurringType: item.recurringType,
            recurringAmount: item.recurringAmount,
            recurringCurrency: item.recurringCurrency,
            parentId: item.parentId,
            hasChildren: item.hasChildren,
            groupId: item.groupId,
            isGroup: item.isGroup,
            assetId: item.assetId,
            assetInstitutionName: item.assetInstitutionName,
            assetName: item.assetName,
            assetDisplayName: item.assetDisplayName,
            assetStatus: item.assetStatus,
            plaidAccountId: item.plaidAccountId,
            plaidAccountName: item.plaidAccountName,
            plaidAccountMask: item.plaidAccountMask,
            institutionName: item.institutionName,
            plaidAccountDisplayName: item.plaidAccountDisplayName,
            plaidMetadata: item.plaidMetadata,
            source: item.source,
            displayName: item.displayName,
            displayNotes: item.displayNotes,
            accountDisplayName: item.accountDisplayName,
            externalId: item.externalId,
            tags: makeTags(from: item.tags)
        )
    }

    private func apply(_ item: FinanceCoreSDK.Transaction, to local: PersistenceService.Transaction, context: ModelContext) {
        local.date = item.date
        local.payee = item.payee
        local.amount = item.amount
        local.currency = item.currency
        local.toBase = item.toBase
        local.notes = item.notes
        local.originalName = item.originalName
        local.categoryId = item.categoryId
        local.categoryName = item.categoryName
        local.categoryGroupId = item.categoryGroupId
        local.categoryGroupName = item.categoryGroupName
        local.status = item.status
        local.isIncome = item.isIncome
        local.isPending = item.isPending
        local.excludeFromBudget = item.excludeFromBudget
        local.excludeFromTotals = item.excludeFromTotals
        local.createdAt = item.createdAt
        local.updatedAt = item.updatedAt
        local.recurringId = item.recurringId
        local.recurringPayee = item.recurringPayee
        local.recurringDescription = item.recurringDescription
        local.recurringCadence = item.recurringCadence
        local.recurringGranularity = item.recurringGranularity
        local.recurringQuantity = item.recurringQuantity
        local.recurringType = item.recurringType
        local.recurringAmount = item.recurringAmount
        local.recurringCurrency = item.recurringCurrency
        local.parentId = item.parentId
        local.hasChildren = item.hasChildren
        local.groupId = item.groupId
        local.isGroup = item.isGroup
        local.assetId = item.assetId
        local.assetInstitutionName = item.assetInstitutionName
        local.assetName = item.assetName
        local.assetDisplayName = item.assetDisplayName
        local.assetStatus = item.assetStatus
        local.plaidAccountId = item.plaidAccountId
        local.plaidAccountName = item.plaidAccountName
        local.plaidAccountMask = item.plaidAccountMask
        local.institutionName = item.institutionName
        local.plaidAccountDisplayName = item.plaidAccountDisplayName
        local.plaidMetadata = item.plaidMetadata
        local.source = item.source
        local.displayName = item.displayName
        local.displayNotes = item.displayNotes
        local.accountDisplayName = item.accountDisplayName
        local.externalId = item.externalId

        for tag in local.tags { context.delete(tag) }
        local.tags = makeTags(from: item.tags)
    }

    private func makeTags(from tags: [FinanceCoreSDK.Tag]) -> [PersistenceService.Tag] {
        tags.map { PersistenceService.Tag(lunchMoneyId: $0.lunchMoneyId, name: $0.name) }
    }
}
