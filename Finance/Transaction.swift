//
//  Transaction.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import Foundation

struct Transaction: Codable, Identifiable {
    let id: Int
    let date: String
    let payee: String
    let amount: String
    let currency: String
    let toBase: Double
    let notes: String?
    let originalName: String

    // Category
    let categoryId: Int?
    let categoryName: String?
    let categoryGroupId: Int?
    let categoryGroupName: String?

    // Status & Flags
    let status: String
    let isIncome: Bool
    let isPending: Bool
    let excludeFromBudget: Bool
    let excludeFromTotals: Bool

    // Timestamps
    let createdAt: String
    let updatedAt: String

    // Recurring
    let recurringId: Int?
    let recurringPayee: String?
    let recurringDescription: String?
    let recurringCadence: String?
    let recurringGranularity: String?
    let recurringQuantity: Int?
    let recurringType: String?
    let recurringAmount: String?
    let recurringCurrency: String?

    // Grouping
    let parentId: Int?
    let hasChildren: Bool
    let groupId: Int?
    let isGroup: Bool

    // Asset
    let assetId: Int?
    let assetInstitutionName: String?
    let assetName: String?
    let assetDisplayName: String?
    let assetStatus: String?

    // Plaid
    let plaidAccountId: Int?
    let plaidAccountName: String?
    let plaidAccountMask: String?
    let institutionName: String?
    let plaidAccountDisplayName: String?
    let plaidMetadata: String?

    // Display & Source
    let source: String?
    let displayName: String?
    let displayNotes: String?
    let accountDisplayName: String?
    let externalId: String?

    // Tags
    let tags: [Tag]?

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case payee
        case amount
        case currency
        case toBase = "to_base"
        case notes
        case originalName = "original_name"
        case categoryId = "category_id"
        case categoryName = "category_name"
        case categoryGroupId = "category_group_id"
        case categoryGroupName = "category_group_name"
        case status
        case isIncome = "is_income"
        case isPending = "is_pending"
        case excludeFromBudget = "exclude_from_budget"
        case excludeFromTotals = "exclude_from_totals"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case recurringId = "recurring_id"
        case recurringPayee = "recurring_payee"
        case recurringDescription = "recurring_description"
        case recurringCadence = "recurring_cadence"
        case recurringGranularity = "recurring_granularity"
        case recurringQuantity = "recurring_quantity"
        case recurringType = "recurring_type"
        case recurringAmount = "recurring_amount"
        case recurringCurrency = "recurring_currency"
        case parentId = "parent_id"
        case hasChildren = "has_children"
        case groupId = "group_id"
        case isGroup = "is_group"
        case assetId = "asset_id"
        case assetInstitutionName = "asset_institution_name"
        case assetName = "asset_name"
        case assetDisplayName = "asset_display_name"
        case assetStatus = "asset_status"
        case plaidAccountId = "plaid_account_id"
        case plaidAccountName = "plaid_account_name"
        case plaidAccountMask = "plaid_account_mask"
        case institutionName = "institution_name"
        case plaidAccountDisplayName = "plaid_account_display_name"
        case plaidMetadata = "plaid_metadata"
        case source
        case displayName = "display_name"
        case displayNotes = "display_notes"
        case accountDisplayName = "account_display_name"
        case externalId = "external_id"
        case tags
    }
}

struct Tag: Codable {
    let id: Int?
    let name: String?
}

struct TransactionsResponse: Codable {
    let transactions: [Transaction]
}
