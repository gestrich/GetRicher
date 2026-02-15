import Foundation

public struct Transaction: Identifiable, Sendable {
    public let id: Int
    public let date: String
    public let payee: String
    public let amount: String
    public let currency: String
    public let toBase: Double
    public let notes: String?
    public let originalName: String
    public let categoryId: Int?
    public let categoryName: String?
    public let categoryGroupId: Int?
    public let categoryGroupName: String?
    public let status: String
    public let isIncome: Bool
    public let isPending: Bool
    public let excludeFromBudget: Bool
    public let excludeFromTotals: Bool
    public let createdAt: String
    public let updatedAt: String
    public let recurringId: Int?
    public let recurringPayee: String?
    public let recurringDescription: String?
    public let recurringCadence: String?
    public let recurringGranularity: String?
    public let recurringQuantity: Int?
    public let recurringType: String?
    public let recurringAmount: String?
    public let recurringCurrency: String?
    public let parentId: Int?
    public let hasChildren: Bool
    public let groupId: Int?
    public let isGroup: Bool
    public let assetId: Int?
    public let assetInstitutionName: String?
    public let assetName: String?
    public let assetDisplayName: String?
    public let assetStatus: String?
    public let plaidAccountId: Int?
    public let plaidAccountName: String?
    public let plaidAccountMask: String?
    public let institutionName: String?
    public let plaidAccountDisplayName: String?
    public let plaidMetadata: String?
    public let source: String?
    public let displayName: String?
    public let displayNotes: String?
    public let accountDisplayName: String?
    public let externalId: String?
    public let tags: [Tag]?

    public init(
        id: Int,
        date: String,
        payee: String,
        amount: String,
        currency: String,
        toBase: Double,
        notes: String?,
        originalName: String,
        categoryId: Int?,
        categoryName: String?,
        categoryGroupId: Int?,
        categoryGroupName: String?,
        status: String,
        isIncome: Bool,
        isPending: Bool,
        excludeFromBudget: Bool,
        excludeFromTotals: Bool,
        createdAt: String,
        updatedAt: String,
        recurringId: Int?,
        recurringPayee: String?,
        recurringDescription: String?,
        recurringCadence: String?,
        recurringGranularity: String?,
        recurringQuantity: Int?,
        recurringType: String?,
        recurringAmount: String?,
        recurringCurrency: String?,
        parentId: Int?,
        hasChildren: Bool,
        groupId: Int?,
        isGroup: Bool,
        assetId: Int?,
        assetInstitutionName: String?,
        assetName: String?,
        assetDisplayName: String?,
        assetStatus: String?,
        plaidAccountId: Int?,
        plaidAccountName: String?,
        plaidAccountMask: String?,
        institutionName: String?,
        plaidAccountDisplayName: String?,
        plaidMetadata: String?,
        source: String?,
        displayName: String?,
        displayNotes: String?,
        accountDisplayName: String?,
        externalId: String?,
        tags: [Tag]?
    ) {
        self.id = id
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

public struct Tag: Sendable {
    public let id: Int?
    public let name: String?

    public init(id: Int?, name: String?) {
        self.id = id
        self.name = name
    }
}
