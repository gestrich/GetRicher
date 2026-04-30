import Foundation
import KeychainSDK
import LunchMoneySDK

struct DemoKeychainClient: KeychainClientProtocol {
    func saveAPIToken(_ token: String) throws {}
    func getAPIToken() -> String? { "demo-token" }
    func deleteAPIToken() throws {}
}

struct DemoLunchMoneyClient: LunchMoneyClientProtocol {
    func fetchTransactions(
        token: String,
        accountId: Int?,
        startDate: String,
        endDate: String,
        limit: Int,
        offset: Int
    ) async throws -> TransactionsResponseDTO {
        let allTransactions = Self.getTransactions(accountId: accountId)
        let page = Array(allTransactions.dropFirst(offset).prefix(limit))
        return TransactionsResponseDTO(transactions: page)
    }

    func fetchPlaidAccounts(token: String) async throws -> PlaidAccountsResponseDTO {
        PlaidAccountsResponseDTO(plaidAccounts: [
            PlaidAccountDTO(id: 1, name: "Checking", displayName: "Chase Checking", type: "depository", subtype: "checking", mask: "4521", institutionName: "Chase", status: "active", balance: "4235.67", currency: "usd"),
            PlaidAccountDTO(id: 2, name: "Credit Card", displayName: "Amex Gold", type: "credit", subtype: "credit card", mask: "1008", institutionName: "American Express", status: "active", balance: "1847.32", currency: "usd"),
            PlaidAccountDTO(id: 3, name: "Savings", displayName: "Ally Savings", type: "depository", subtype: "savings", mask: "7890", institutionName: "Ally Bank", status: "active", balance: "12450.00", currency: "usd"),
        ])
    }

    private static var cachedTransactions: [Int?: [TransactionDTO]] = [:]

    private static func getTransactions(accountId: Int?) -> [TransactionDTO] {
        if let cached = cachedTransactions[accountId] {
            return cached
        }
        let transactions = generateTransactions(accountId: accountId)
        cachedTransactions[accountId] = transactions
        return transactions
    }

    private static func generateTransactions(accountId: Int?) -> [TransactionDTO] {
        let vendors: [(payee: String, category: String, amountRange: ClosedRange<Double>, accountId: Int)] = [
            ("Whole Foods Market", "Groceries", 45.00...185.00, 2),
            ("Trader Joe's", "Groceries", 30.00...95.00, 2),
            ("Costco", "Groceries", 120.00...320.00, 1),
            ("Shell Gas Station", "Gas & Fuel", 35.00...72.00, 1),
            ("Chevron", "Gas & Fuel", 40.00...68.00, 1),
            ("Netflix", "Subscriptions", 15.49...15.49, 2),
            ("Spotify", "Subscriptions", 10.99...10.99, 2),
            ("Apple iCloud", "Subscriptions", 2.99...2.99, 2),
            ("Chipotle", "Restaurants", 12.00...18.00, 2),
            ("Starbucks", "Coffee Shops", 5.50...8.75, 2),
            ("Target", "Shopping", 25.00...150.00, 2),
            ("Amazon", "Shopping", 15.00...200.00, 2),
            ("Uber Eats", "Food Delivery", 18.00...45.00, 2),
            ("PG&E", "Utilities", 85.00...145.00, 1),
            ("Comcast Internet", "Utilities", 79.99...79.99, 1),
            ("Planet Fitness", "Health & Fitness", 24.99...24.99, 1),
            ("CVS Pharmacy", "Health", 8.00...45.00, 2),
            ("Home Depot", "Home", 30.00...250.00, 1),
            ("Olive Garden", "Restaurants", 35.00...75.00, 2),
            ("Thai Basil", "Restaurants", 22.00...48.00, 2),
        ]

        let nowTs = "2026-03-20T12:00:00.000Z"
        var transactions: [TransactionDTO] = []
        var id = 1000

        // Generate transactions over last 3 months including recent dates
        let dates = [
            "2026-03-20", "2026-03-19", "2026-03-18", "2026-03-17", "2026-03-16",
            "2026-03-15", "2026-03-14", "2026-03-13", "2026-03-12", "2026-03-10",
            "2026-03-08", "2026-03-06", "2026-03-04", "2026-03-02", "2026-03-01",
            "2026-02-28", "2026-02-25", "2026-02-22", "2026-02-20",
            "2026-02-18", "2026-02-15", "2026-02-12", "2026-02-10", "2026-02-08",
            "2026-02-06", "2026-02-04", "2026-02-02", "2026-02-01",
            "2026-01-30", "2026-01-28", "2026-01-25", "2026-01-22", "2026-01-20",
            "2026-01-15", "2026-01-10", "2026-01-05", "2026-01-01",
        ]

        // Recent dates that should be pending (last 2 days)
        let pendingDates: Set<String> = ["2026-03-20", "2026-03-19"]

        for date in dates {
            // 1-3 transactions per date
            let count = [1, 1, 2, 2, 2, 3].randomElement()!
            for _ in 0..<count {
                let vendor = vendors.randomElement()!
                if let accountId, vendor.accountId != accountId { continue }
                let amount = Double.random(in: vendor.amountRange)
                let amountStr = String(format: "%.2f", amount)
                let isPending = pendingDates.contains(date)
                id += 1
                transactions.append(TransactionDTO(
                    id: id,
                    date: date,
                    payee: vendor.payee,
                    amount: amountStr,
                    currency: "usd",
                    toBase: amount,
                    notes: nil,
                    originalName: vendor.payee,
                    categoryId: 1,
                    categoryName: vendor.category,
                    categoryGroupId: nil,
                    categoryGroupName: nil,
                    status: isPending ? "pending" : "cleared",
                    isIncome: false,
                    isPending: isPending,
                    excludeFromBudget: false,
                    excludeFromTotals: false,
                    createdAt: nowTs,
                    updatedAt: nowTs,
                    recurringId: nil,
                    recurringPayee: nil,
                    recurringDescription: nil,
                    recurringCadence: nil,
                    recurringGranularity: nil,
                    recurringQuantity: nil,
                    recurringType: nil,
                    recurringAmount: nil,
                    recurringCurrency: nil,
                    parentId: nil,
                    hasChildren: false,
                    groupId: nil,
                    isGroup: false,
                    assetId: nil,
                    assetInstitutionName: nil,
                    assetName: nil,
                    assetDisplayName: nil,
                    assetStatus: nil,
                    plaidAccountId: vendor.accountId,
                    plaidAccountName: nil,
                    plaidAccountMask: nil,
                    institutionName: nil,
                    plaidAccountDisplayName: vendor.accountId == 1 ? "Chase Checking" : "Amex Gold",
                    plaidMetadata: nil,
                    source: "plaid",
                    displayName: vendor.payee,
                    displayNotes: nil,
                    accountDisplayName: vendor.accountId == 1 ? "Chase Checking" : "Amex Gold",
                    externalId: nil,
                    tags: nil
                ))
            }
        }

        // Add transfer payment transactions (credits on the credit card)
        let transferPayments: [(date: String, payee: String, amount: Double, sourceDesc: String)] = [
            ("2026-03-14", "ONLINE PAYMENT - THANK YOU", 500.00, "Chase Checking"),
            ("2026-03-07", "ONLINE PAYMENT - THANK YOU", 350.00, "Chase Checking"),
            ("2026-02-28", "ONLINE PAYMENT - THANK YOU", 400.00, "Chase Checking"),
            ("2026-03-10", "MOBILE PAYMENT - THANK YOU", 150.00, "Ally Savings"),
            ("2026-02-24", "MOBILE PAYMENT - THANK YOU", 120.00, "Ally Savings"),
        ]

        for payment in transferPayments {
            if let accountId, accountId != 2 { continue }
            id += 1
            transactions.append(TransactionDTO(
                id: id,
                date: payment.date,
                payee: payment.payee,
                amount: String(format: "-%.2f", payment.amount),
                currency: "usd",
                toBase: -payment.amount,
                notes: "Payment received",
                originalName: payment.payee,
                categoryId: nil,
                categoryName: nil,
                categoryGroupId: nil,
                categoryGroupName: nil,
                status: "cleared",
                isIncome: false,
                isPending: false,
                excludeFromBudget: false,
                excludeFromTotals: false,
                createdAt: nowTs,
                updatedAt: nowTs,
                recurringId: nil,
                recurringPayee: nil,
                recurringDescription: nil,
                recurringCadence: nil,
                recurringGranularity: nil,
                recurringQuantity: nil,
                recurringType: nil,
                recurringAmount: nil,
                recurringCurrency: nil,
                parentId: nil,
                hasChildren: false,
                groupId: nil,
                isGroup: false,
                assetId: nil,
                assetInstitutionName: nil,
                assetName: nil,
                assetDisplayName: nil,
                assetStatus: nil,
                plaidAccountId: 2,
                plaidAccountName: nil,
                plaidAccountMask: nil,
                institutionName: nil,
                plaidAccountDisplayName: "Amex Gold",
                plaidMetadata: nil,
                source: "plaid",
                displayName: payment.payee,
                displayNotes: nil,
                accountDisplayName: "Amex Gold",
                externalId: nil,
                tags: nil
            ))
        }

        // Add a couple income transactions
        for date in ["2026-03-15", "2026-03-01", "2026-02-15", "2026-02-01"] {
            id += 1
            transactions.append(TransactionDTO(
                id: id,
                date: date,
                payee: "Employer - Direct Deposit",
                amount: "3250.00",
                currency: "usd",
                toBase: 3250.00,
                notes: "Bi-weekly paycheck",
                originalName: "EMPLOYER DIRECT DEP",
                categoryId: 2,
                categoryName: "Income",
                categoryGroupId: nil,
                categoryGroupName: nil,
                status: "cleared",
                isIncome: true,
                isPending: false,
                excludeFromBudget: false,
                excludeFromTotals: false,
                createdAt: nowTs,
                updatedAt: nowTs,
                recurringId: 1,
                recurringPayee: "Employer",
                recurringDescription: "Bi-weekly salary",
                recurringCadence: "twice a month",
                recurringGranularity: nil,
                recurringQuantity: nil,
                recurringType: "cleared",
                recurringAmount: "3250.00",
                recurringCurrency: "usd",
                parentId: nil,
                hasChildren: false,
                groupId: nil,
                isGroup: false,
                assetId: nil,
                assetInstitutionName: nil,
                assetName: nil,
                assetDisplayName: nil,
                assetStatus: nil,
                plaidAccountId: 1,
                plaidAccountName: nil,
                plaidAccountMask: nil,
                institutionName: nil,
                plaidAccountDisplayName: "Chase Checking",
                plaidMetadata: nil,
                source: "plaid",
                displayName: "Employer - Direct Deposit",
                displayNotes: nil,
                accountDisplayName: "Chase Checking",
                externalId: nil,
                tags: nil
            ))
        }

        return transactions
    }
}
