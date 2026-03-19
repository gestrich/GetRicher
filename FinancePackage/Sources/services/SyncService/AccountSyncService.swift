import Foundation
import LunchMoneySDK
import PersistenceService
import SwiftData

public struct AccountSyncService: Sendable {

    public init() {}

    /// Sync fetched account DTOs into SwiftData, returning what changed.
    @MainActor
    public func sync(
        dtos: [PlaidAccountDTO],
        context: ModelContext
    ) throws -> SyncResult {
        let fetchedIds = Set(dtos.map(\.id))

        let descriptor = FetchDescriptor<PlaidAccount>()
        let existing = try context.fetch(descriptor)
        let existingByLMId = Dictionary(uniqueKeysWithValues: existing.map { ($0.lunchMoneyId, $0) })

        var inserted = 0
        var updated = 0

        for dto in dtos {
            if let local = existingByLMId[dto.id] {
                if hasChanges(dto: dto, local: local) {
                    applyDTO(dto, to: local)
                    updated += 1
                }
            } else {
                let account = PlaidAccount(
                    lunchMoneyId: dto.id,
                    name: dto.name,
                    displayName: dto.displayName,
                    type: dto.type,
                    subtype: dto.subtype,
                    mask: dto.mask,
                    institutionName: dto.institutionName,
                    status: dto.status,
                    balance: dto.balance,
                    currency: dto.currency
                )
                context.insert(account)
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

    private func hasChanges(dto: PlaidAccountDTO, local: PlaidAccount) -> Bool {
        local.name != dto.name
            || local.displayName != dto.displayName
            || local.type != dto.type
            || local.subtype != dto.subtype
            || local.mask != dto.mask
            || local.institutionName != dto.institutionName
            || local.status != dto.status
            || local.balance != dto.balance
            || local.currency != dto.currency
    }

    private func applyDTO(_ dto: PlaidAccountDTO, to local: PlaidAccount) {
        local.name = dto.name
        local.displayName = dto.displayName
        local.type = dto.type
        local.subtype = dto.subtype
        local.mask = dto.mask
        local.institutionName = dto.institutionName
        local.status = dto.status
        local.balance = dto.balance
        local.currency = dto.currency
    }
}
