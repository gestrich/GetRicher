import CoreService
import LunchMoneySDK

enum TransactionMapper {
    static func map(_ apiTransaction: LunchMoneyTransaction) -> Transaction {
        Transaction(
            id: apiTransaction.id,
            date: apiTransaction.date,
            payee: apiTransaction.payee,
            amount: apiTransaction.amount,
            currency: apiTransaction.currency,
            toBase: apiTransaction.toBase,
            notes: apiTransaction.notes,
            originalName: apiTransaction.originalName,
            categoryId: apiTransaction.categoryId,
            categoryName: apiTransaction.categoryName,
            categoryGroupId: apiTransaction.categoryGroupId,
            categoryGroupName: apiTransaction.categoryGroupName,
            status: apiTransaction.status,
            isIncome: apiTransaction.isIncome,
            isPending: apiTransaction.isPending,
            excludeFromBudget: apiTransaction.excludeFromBudget,
            excludeFromTotals: apiTransaction.excludeFromTotals,
            createdAt: apiTransaction.createdAt,
            updatedAt: apiTransaction.updatedAt,
            recurringId: apiTransaction.recurringId,
            recurringPayee: apiTransaction.recurringPayee,
            recurringDescription: apiTransaction.recurringDescription,
            recurringCadence: apiTransaction.recurringCadence,
            recurringGranularity: apiTransaction.recurringGranularity,
            recurringQuantity: apiTransaction.recurringQuantity,
            recurringType: apiTransaction.recurringType,
            recurringAmount: apiTransaction.recurringAmount,
            recurringCurrency: apiTransaction.recurringCurrency,
            parentId: apiTransaction.parentId,
            hasChildren: apiTransaction.hasChildren,
            groupId: apiTransaction.groupId,
            isGroup: apiTransaction.isGroup,
            assetId: apiTransaction.assetId,
            assetInstitutionName: apiTransaction.assetInstitutionName,
            assetName: apiTransaction.assetName,
            assetDisplayName: apiTransaction.assetDisplayName,
            assetStatus: apiTransaction.assetStatus,
            plaidAccountId: apiTransaction.plaidAccountId,
            plaidAccountName: apiTransaction.plaidAccountName,
            plaidAccountMask: apiTransaction.plaidAccountMask,
            institutionName: apiTransaction.institutionName,
            plaidAccountDisplayName: apiTransaction.plaidAccountDisplayName,
            plaidMetadata: apiTransaction.plaidMetadata,
            source: apiTransaction.source,
            displayName: apiTransaction.displayName,
            displayNotes: apiTransaction.displayNotes,
            accountDisplayName: apiTransaction.accountDisplayName,
            externalId: apiTransaction.externalId,
            tags: apiTransaction.tags?.map { Tag(id: $0.id, name: $0.name) }
        )
    }

    static func map(_ apiAccount: LunchMoneyPlaidAccount) -> PlaidAccount {
        PlaidAccount(
            id: apiAccount.id,
            name: apiAccount.name,
            displayName: apiAccount.displayName,
            type: apiAccount.type,
            subtype: apiAccount.subtype,
            mask: apiAccount.mask,
            institutionName: apiAccount.institutionName,
            status: apiAccount.status,
            balance: apiAccount.balance,
            currency: apiAccount.currency
        )
    }
}
