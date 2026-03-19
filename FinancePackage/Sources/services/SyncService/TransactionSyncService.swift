import Foundation
import LunchMoneySDK
import PersistenceService
import SwiftData

public struct TransactionSyncService: Sendable {

    public init() {}

    /// Sync fetched transaction DTOs into SwiftData, returning what changed.
    ///
    /// - Inserts new transactions not in the local store
    /// - Updates existing transactions where `updatedAt` differs
    /// - Deletes local transactions (within the fetched date range) not in the fetched set
    @MainActor
    public func sync(
        dtos: [TransactionDTO],
        context: ModelContext
    ) throws -> SyncResult {
        let fetchedIds = Set(dtos.map(\.id))

        // Build lookup of existing local records by lunchMoneyId
        let descriptor = FetchDescriptor<Transaction>()
        let existing = try context.fetch(descriptor)
        let existingByLMId = Dictionary(uniqueKeysWithValues: existing.compactMap { tx in
            (tx.lunchMoneyId, tx)
        })

        var inserted = 0
        var updated = 0

        for dto in dtos {
            if let local = existingByLMId[dto.id] {
                // Update only if changed
                if local.updatedAt != dto.updatedAt {
                    applyDTO(dto, to: local, context: context)
                    updated += 1
                }
            } else {
                // Insert new
                let transaction = makeTransaction(from: dto, context: context)
                context.insert(transaction)
                inserted += 1
            }
        }

        // Delete local records not in fetched set
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

    private func makeTransaction(from dto: TransactionDTO, context: ModelContext) -> Transaction {
        let transaction = Transaction(
            lunchMoneyId: dto.id,
            date: dto.date,
            payee: dto.payee,
            amount: dto.amount,
            currency: dto.currency,
            toBase: dto.toBase,
            notes: dto.notes,
            originalName: dto.originalName,
            categoryId: dto.categoryId,
            categoryName: dto.categoryName,
            categoryGroupId: dto.categoryGroupId,
            categoryGroupName: dto.categoryGroupName,
            status: dto.status,
            isIncome: dto.isIncome,
            isPending: dto.isPending,
            excludeFromBudget: dto.excludeFromBudget,
            excludeFromTotals: dto.excludeFromTotals,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            recurringId: dto.recurringId,
            recurringPayee: dto.recurringPayee,
            recurringDescription: dto.recurringDescription,
            recurringCadence: dto.recurringCadence,
            recurringGranularity: dto.recurringGranularity,
            recurringQuantity: dto.recurringQuantity,
            recurringType: dto.recurringType,
            recurringAmount: dto.recurringAmount,
            recurringCurrency: dto.recurringCurrency,
            parentId: dto.parentId,
            hasChildren: dto.hasChildren,
            groupId: dto.groupId,
            isGroup: dto.isGroup,
            assetId: dto.assetId,
            assetInstitutionName: dto.assetInstitutionName,
            assetName: dto.assetName,
            assetDisplayName: dto.assetDisplayName,
            assetStatus: dto.assetStatus,
            plaidAccountId: dto.plaidAccountId,
            plaidAccountName: dto.plaidAccountName,
            plaidAccountMask: dto.plaidAccountMask,
            institutionName: dto.institutionName,
            plaidAccountDisplayName: dto.plaidAccountDisplayName,
            plaidMetadata: dto.plaidMetadata,
            source: dto.source,
            displayName: dto.displayName,
            displayNotes: dto.displayNotes,
            accountDisplayName: dto.accountDisplayName,
            externalId: dto.externalId,
            tags: makeTags(from: dto.tags)
        )
        return transaction
    }

    private func applyDTO(_ dto: TransactionDTO, to local: Transaction, context: ModelContext) {
        local.date = dto.date
        local.payee = dto.payee
        local.amount = dto.amount
        local.currency = dto.currency
        local.toBase = dto.toBase
        local.notes = dto.notes
        local.originalName = dto.originalName
        local.categoryId = dto.categoryId
        local.categoryName = dto.categoryName
        local.categoryGroupId = dto.categoryGroupId
        local.categoryGroupName = dto.categoryGroupName
        local.status = dto.status
        local.isIncome = dto.isIncome
        local.isPending = dto.isPending
        local.excludeFromBudget = dto.excludeFromBudget
        local.excludeFromTotals = dto.excludeFromTotals
        local.createdAt = dto.createdAt
        local.updatedAt = dto.updatedAt
        local.recurringId = dto.recurringId
        local.recurringPayee = dto.recurringPayee
        local.recurringDescription = dto.recurringDescription
        local.recurringCadence = dto.recurringCadence
        local.recurringGranularity = dto.recurringGranularity
        local.recurringQuantity = dto.recurringQuantity
        local.recurringType = dto.recurringType
        local.recurringAmount = dto.recurringAmount
        local.recurringCurrency = dto.recurringCurrency
        local.parentId = dto.parentId
        local.hasChildren = dto.hasChildren
        local.groupId = dto.groupId
        local.isGroup = dto.isGroup
        local.assetId = dto.assetId
        local.assetInstitutionName = dto.assetInstitutionName
        local.assetName = dto.assetName
        local.assetDisplayName = dto.assetDisplayName
        local.assetStatus = dto.assetStatus
        local.plaidAccountId = dto.plaidAccountId
        local.plaidAccountName = dto.plaidAccountName
        local.plaidAccountMask = dto.plaidAccountMask
        local.institutionName = dto.institutionName
        local.plaidAccountDisplayName = dto.plaidAccountDisplayName
        local.plaidMetadata = dto.plaidMetadata
        local.source = dto.source
        local.displayName = dto.displayName
        local.displayNotes = dto.displayNotes
        local.accountDisplayName = dto.accountDisplayName
        local.externalId = dto.externalId

        // Replace tags
        for tag in local.tags {
            context.delete(tag)
        }
        local.tags = makeTags(from: dto.tags)
    }

    private func makeTags(from dtoTags: [TagDTO]?) -> [Tag] {
        guard let dtoTags else { return [] }
        return dtoTags.map { Tag(lunchMoneyId: $0.id, name: $0.name) }
    }
}
