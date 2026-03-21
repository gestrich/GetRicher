import Foundation
import SwiftData

@Model
public final class Transaction {
    #Unique<Transaction>([\.lunchMoneyId])

    public var lunchMoneyId: Int
    public var date: String
    public var payee: String
    public var amount: String
    public var currency: String
    public var toBase: Double
    public var notes: String?
    public var originalName: String
    public var categoryId: Int?
    public var categoryName: String?
    public var categoryGroupId: Int?
    public var categoryGroupName: String?
    public var status: String
    public var isIncome: Bool
    public var isPending: Bool
    public var excludeFromBudget: Bool
    public var excludeFromTotals: Bool
    public var createdAt: String
    public var updatedAt: String
    public var recurringId: Int?
    public var recurringPayee: String?
    public var recurringDescription: String?
    public var recurringCadence: String?
    public var recurringGranularity: String?
    public var recurringQuantity: Int?
    public var recurringType: String?
    public var recurringAmount: String?
    public var recurringCurrency: String?
    public var parentId: Int?
    public var hasChildren: Bool
    public var groupId: Int?
    public var isGroup: Bool
    public var assetId: Int?
    public var assetInstitutionName: String?
    public var assetName: String?
    public var assetDisplayName: String?
    public var assetStatus: String?
    public var plaidAccountId: Int?
    public var plaidAccountName: String?
    public var plaidAccountMask: String?
    public var institutionName: String?
    public var plaidAccountDisplayName: String?
    public var plaidMetadata: String?
    public var source: String?
    public var displayName: String?
    public var displayNotes: String?
    public var accountDisplayName: String?
    public var externalId: String?
    @Relationship(deleteRule: .cascade) public var tags: [Tag]
    public var localCategory: Category?

    public init(
        lunchMoneyId: Int,
        date: String,
        payee: String,
        amount: String,
        currency: String,
        toBase: Double,
        notes: String? = nil,
        originalName: String,
        categoryId: Int? = nil,
        categoryName: String? = nil,
        categoryGroupId: Int? = nil,
        categoryGroupName: String? = nil,
        status: String,
        isIncome: Bool,
        isPending: Bool,
        excludeFromBudget: Bool,
        excludeFromTotals: Bool,
        createdAt: String,
        updatedAt: String,
        recurringId: Int? = nil,
        recurringPayee: String? = nil,
        recurringDescription: String? = nil,
        recurringCadence: String? = nil,
        recurringGranularity: String? = nil,
        recurringQuantity: Int? = nil,
        recurringType: String? = nil,
        recurringAmount: String? = nil,
        recurringCurrency: String? = nil,
        parentId: Int? = nil,
        hasChildren: Bool,
        groupId: Int? = nil,
        isGroup: Bool,
        assetId: Int? = nil,
        assetInstitutionName: String? = nil,
        assetName: String? = nil,
        assetDisplayName: String? = nil,
        assetStatus: String? = nil,
        plaidAccountId: Int? = nil,
        plaidAccountName: String? = nil,
        plaidAccountMask: String? = nil,
        institutionName: String? = nil,
        plaidAccountDisplayName: String? = nil,
        plaidMetadata: String? = nil,
        source: String? = nil,
        displayName: String? = nil,
        displayNotes: String? = nil,
        accountDisplayName: String? = nil,
        externalId: String? = nil,
        tags: [Tag] = []
    ) {
        self.lunchMoneyId = lunchMoneyId
        self.date = date
        self.payee = payee
        self.amount = amount
        self.currency = currency
        self.toBase = toBase
        self.notes = notes
        self.originalName = originalName
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryGroupId = categoryGroupId
        self.categoryGroupName = categoryGroupName
        self.status = status
        self.isIncome = isIncome
        self.isPending = isPending
        self.excludeFromBudget = excludeFromBudget
        self.excludeFromTotals = excludeFromTotals
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recurringId = recurringId
        self.recurringPayee = recurringPayee
        self.recurringDescription = recurringDescription
        self.recurringCadence = recurringCadence
        self.recurringGranularity = recurringGranularity
        self.recurringQuantity = recurringQuantity
        self.recurringType = recurringType
        self.recurringAmount = recurringAmount
        self.recurringCurrency = recurringCurrency
        self.parentId = parentId
        self.hasChildren = hasChildren
        self.groupId = groupId
        self.isGroup = isGroup
        self.assetId = assetId
        self.assetInstitutionName = assetInstitutionName
        self.assetName = assetName
        self.assetDisplayName = assetDisplayName
        self.assetStatus = assetStatus
        self.plaidAccountId = plaidAccountId
        self.plaidAccountName = plaidAccountName
        self.plaidAccountMask = plaidAccountMask
        self.institutionName = institutionName
        self.plaidAccountDisplayName = plaidAccountDisplayName
        self.plaidMetadata = plaidMetadata
        self.source = source
        self.displayName = displayName
        self.displayNotes = displayNotes
        self.accountDisplayName = accountDisplayName
        self.externalId = externalId
        self.tags = tags
    }
}
