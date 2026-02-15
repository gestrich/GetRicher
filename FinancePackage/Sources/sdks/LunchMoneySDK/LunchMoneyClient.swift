import Foundation

public struct LunchMoneyClient: Sendable {
    private let baseURL: String

    public init(baseURL: String = "https://dev.lunchmoney.app/v1") {
        self.baseURL = baseURL
    }

    public func fetchTransactions(
        token: String,
        accountId: Int?,
        startDate: String,
        endDate: String,
        limit: Int,
        offset: Int
    ) async throws -> TransactionsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/transactions")
        var queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        if let accountId {
            queryItems.append(URLQueryItem(name: "plaid_account_id", value: "\(accountId)"))
        }

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw LunchMoneyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LunchMoneyError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LunchMoneyError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(TransactionsResponse.self, from: data)
    }

    public func fetchPlaidAccounts(token: String) async throws -> PlaidAccountsResponse {
        guard let url = URL(string: "\(baseURL)/plaid_accounts") else {
            throw LunchMoneyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LunchMoneyError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LunchMoneyError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(PlaidAccountsResponse.self, from: data)
    }
}

public enum LunchMoneyError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case serverError(Int)
}

public struct TransactionsResponse: Codable, Sendable {
    public let transactions: [LunchMoneyTransaction]
}

public struct LunchMoneyTransaction: Codable, Sendable {
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
    public let tags: [LunchMoneyTag]?

    enum CodingKeys: String, CodingKey {
        case id, date, payee, amount, currency, notes, status, source, tags
        case toBase = "to_base"
        case originalName = "original_name"
        case categoryId = "category_id"
        case categoryName = "category_name"
        case categoryGroupId = "category_group_id"
        case categoryGroupName = "category_group_name"
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
        case displayName = "display_name"
        case displayNotes = "display_notes"
        case accountDisplayName = "account_display_name"
        case externalId = "external_id"
    }
}

public struct LunchMoneyTag: Codable, Sendable {
    public let id: Int?
    public let name: String?
}

public struct PlaidAccountsResponse: Codable, Sendable {
    public let plaidAccounts: [LunchMoneyPlaidAccount]

    enum CodingKeys: String, CodingKey {
        case plaidAccounts = "plaid_accounts"
    }
}

public struct LunchMoneyPlaidAccount: Codable, Sendable {
    public let id: Int
    public let name: String
    public let displayName: String
    public let type: String
    public let subtype: String
    public let mask: String
    public let institutionName: String
    public let status: String
    public let balance: String
    public let currency: String

    enum CodingKeys: String, CodingKey {
        case id, name, type, subtype, mask, status, balance, currency
        case displayName = "display_name"
        case institutionName = "institution_name"
    }
}
