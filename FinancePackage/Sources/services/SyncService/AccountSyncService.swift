import FinanceCoreSDK
import PersistenceService
import SwiftData

public struct AccountSyncService: Sendable {

    public init() {}

    @MainActor
    public func sync(
        accounts: [FinanceCoreSDK.Account],
        context: ModelContext
    ) throws -> SyncResult {
        let fetchedIds = Set(accounts.map(\.lunchMoneyId))

        let descriptor = FetchDescriptor<PlaidAccount>()
        let existing = try context.fetch(descriptor)
        let existingByLMId = Dictionary(uniqueKeysWithValues: existing.map { ($0.lunchMoneyId, $0) })

        var inserted = 0
        var updated = 0

        for account in accounts {
            if let local = existingByLMId[account.lunchMoneyId] {
                if hasChanges(account: account, local: local) {
                    apply(account, to: local)
                    updated += 1
                }
            } else {
                let local = PlaidAccount(
                    lunchMoneyId: account.lunchMoneyId,
                    name: account.name,
                    displayName: account.displayName,
                    type: account.type,
                    subtype: account.subtype,
                    mask: account.mask,
                    institutionName: account.institutionName,
                    status: account.status,
                    balance: account.balance,
                    currency: account.currency
                )
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

    private func hasChanges(account: FinanceCoreSDK.Account, local: PlaidAccount) -> Bool {
        local.name != account.name
            || local.displayName != account.displayName
            || local.type != account.type
            || local.subtype != account.subtype
            || local.mask != account.mask
            || local.institutionName != account.institutionName
            || local.status != account.status
            || local.balance != account.balance
            || local.currency != account.currency
    }

    private func apply(_ account: FinanceCoreSDK.Account, to local: PlaidAccount) {
        local.name = account.name
        local.displayName = account.displayName
        local.type = account.type
        local.subtype = account.subtype
        local.mask = account.mask
        local.institutionName = account.institutionName
        local.status = account.status
        local.balance = account.balance
        local.currency = account.currency
    }
}
