import FinanceCoreSDK
import Foundation
import SwiftData

extension Transaction {
    @MainActor
    public func toDomain() -> FinanceCoreSDK.Transaction {
        FinanceCoreSDK.Transaction(
            lunchMoneyId: lunchMoneyId,
            date: date,
            payee: payee,
            amount: amount,
            currency: currency,
            toBase: toBase,
            notes: notes,
            originalName: originalName,
            categoryId: categoryId,
            categoryName: categoryName,
            categoryGroupId: categoryGroupId,
            categoryGroupName: categoryGroupName,
            status: status,
            isIncome: isIncome,
            isPending: isPending,
            excludeFromBudget: excludeFromBudget,
            excludeFromTotals: excludeFromTotals,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recurringId: recurringId,
            recurringPayee: recurringPayee,
            recurringDescription: recurringDescription,
            recurringCadence: recurringCadence,
            recurringGranularity: recurringGranularity,
            recurringQuantity: recurringQuantity,
            recurringType: recurringType,
            recurringAmount: recurringAmount,
            recurringCurrency: recurringCurrency,
            parentId: parentId,
            hasChildren: hasChildren,
            groupId: groupId,
            isGroup: isGroup,
            assetId: assetId,
            assetInstitutionName: assetInstitutionName,
            assetName: assetName,
            assetDisplayName: assetDisplayName,
            assetStatus: assetStatus,
            plaidAccountId: plaidAccountId,
            plaidAccountName: plaidAccountName,
            plaidAccountMask: plaidAccountMask,
            institutionName: institutionName,
            plaidAccountDisplayName: plaidAccountDisplayName,
            plaidMetadata: plaidMetadata,
            source: source,
            displayName: displayName,
            displayNotes: displayNotes,
            accountDisplayName: accountDisplayName,
            externalId: externalId,
            tags: tags.map { $0.toDomain() }
        )
    }

    convenience init(from domain: FinanceCoreSDK.Transaction) {
        self.init(
            lunchMoneyId: domain.lunchMoneyId,
            date: domain.date,
            payee: domain.payee,
            amount: domain.amount,
            currency: domain.currency,
            toBase: domain.toBase,
            notes: domain.notes,
            originalName: domain.originalName,
            categoryId: domain.categoryId,
            categoryName: domain.categoryName,
            categoryGroupId: domain.categoryGroupId,
            categoryGroupName: domain.categoryGroupName,
            status: domain.status,
            isIncome: domain.isIncome,
            isPending: domain.isPending,
            excludeFromBudget: domain.excludeFromBudget,
            excludeFromTotals: domain.excludeFromTotals,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            recurringId: domain.recurringId,
            recurringPayee: domain.recurringPayee,
            recurringDescription: domain.recurringDescription,
            recurringCadence: domain.recurringCadence,
            recurringGranularity: domain.recurringGranularity,
            recurringQuantity: domain.recurringQuantity,
            recurringType: domain.recurringType,
            recurringAmount: domain.recurringAmount,
            recurringCurrency: domain.recurringCurrency,
            parentId: domain.parentId,
            hasChildren: domain.hasChildren,
            groupId: domain.groupId,
            isGroup: domain.isGroup,
            assetId: domain.assetId,
            assetInstitutionName: domain.assetInstitutionName,
            assetName: domain.assetName,
            assetDisplayName: domain.assetDisplayName,
            assetStatus: domain.assetStatus,
            plaidAccountId: domain.plaidAccountId,
            plaidAccountName: domain.plaidAccountName,
            plaidAccountMask: domain.plaidAccountMask,
            institutionName: domain.institutionName,
            plaidAccountDisplayName: domain.plaidAccountDisplayName,
            plaidMetadata: domain.plaidMetadata,
            source: domain.source,
            displayName: domain.displayName,
            displayNotes: domain.displayNotes,
            accountDisplayName: domain.accountDisplayName,
            externalId: domain.externalId,
            tags: domain.tags.map { Tag(lunchMoneyId: $0.lunchMoneyId, name: $0.name) }
        )
    }
}

extension Tag {
    @MainActor
    public func toDomain() -> FinanceCoreSDK.Tag {
        FinanceCoreSDK.Tag(lunchMoneyId: lunchMoneyId, name: name)
    }
}

extension PlaidAccount {
    @MainActor
    public func toDomain() -> FinanceCoreSDK.Account {
        FinanceCoreSDK.Account(
            lunchMoneyId: lunchMoneyId,
            name: name,
            displayName: displayName,
            type: type,
            subtype: subtype,
            mask: mask,
            institutionName: institutionName,
            status: status,
            balance: balance,
            currency: currency
        )
    }

    convenience init(from account: FinanceCoreSDK.Account) {
        self.init(
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
    }
}

extension Category {
    @MainActor
    public func toDomain() -> FinanceCoreSDK.Category {
        FinanceCoreSDK.Category(
            id: id,
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            createdAt: createdAt
        )
    }

    convenience init(from category: FinanceCoreSDK.Category) {
        self.init(
            id: category.id,
            name: category.name,
            emoji: category.emoji,
            colorHex: category.colorHex,
            createdAt: category.createdAt
        )
    }
}

extension Vendor {
    @MainActor
    public func toDomain() -> FinanceCoreSDK.Vendor {
        FinanceCoreSDK.Vendor(
            id: id,
            name: name,
            filterText: filterText,
            accountId: accountId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted
        )
    }

    convenience init(from vendor: FinanceCoreSDK.Vendor) {
        self.init(
            id: vendor.id,
            name: vendor.name,
            filterText: vendor.filterText,
            imageData: nil,
            accountId: vendor.accountId,
            createdAt: vendor.createdAt,
            updatedAt: vendor.updatedAt,
            isDeleted: vendor.isDeleted
        )
    }
}

extension TransferRule {
    @MainActor
    public func toDomain() -> FinanceCoreSDK.TransferRule {
        FinanceCoreSDK.TransferRule(
            id: id,
            name: name,
            vendor: vendor?.toDomain(),
            sourceAccountId: sourceAccountId,
            targetAccountId: targetAccountId,
            priority: priority,
            kind: FinanceCoreSDK.RuleKind(rawValue: kindRaw) ?? .transfer,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted
        )
    }

    convenience init(from rule: FinanceCoreSDK.TransferRule) {
        self.init(
            id: rule.id,
            name: rule.name,
            vendor: nil,
            sourceAccountId: rule.sourceAccountId,
            targetAccountId: rule.targetAccountId,
            priority: rule.priority,
            kindRaw: rule.kind.rawValue,
            createdAt: rule.createdAt,
            updatedAt: rule.updatedAt,
            isDeleted: rule.isDeleted
        )
    }
}
