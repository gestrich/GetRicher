import ClientService
import FinanceCoreSDK
import Foundation
import KeychainSDK

struct DemoKeychainClient: KeychainClientProtocol {
    func saveAPIToken(_ token: String) throws {}
    func getAPIToken() -> String? { "demo-token" }
    func deleteAPIToken() throws {}
    func saveUsername(_ username: String) throws {}
    func getUsername() -> String? { "demo" }
    func deleteUsername() throws {}
    func savePassword(_ password: String) throws {}
    func getPassword() -> String? { "demo" }
    func deletePassword() throws {}
    func saveAdminPassword(_ password: String) throws {}
    func getAdminPassword() -> String? { nil }
    func deleteAdminPassword() throws {}
}

struct DemoFinanceSyncClient: FinanceSyncClientProtocol {
    func fetchAccounts(username: String, password: String) async throws -> [Account] {
        [
            Account(lunchMoneyId: 1, name: "Checking", displayName: "Chase Checking", type: "depository", subtype: "checking", mask: "4521", institutionName: "Chase", status: "active", balance: "4235.67", currency: "usd"),
            Account(lunchMoneyId: 2, name: "Credit Card", displayName: "Amex Gold", type: "credit", subtype: "credit card", mask: "1008", institutionName: "American Express", status: "active", balance: "1847.32", currency: "usd"),
            Account(lunchMoneyId: 3, name: "Savings", displayName: "Ally Savings", type: "depository", subtype: "savings", mask: "7890", institutionName: "Ally Bank", status: "active", balance: "12450.00", currency: "usd"),
        ]
    }

    func fetchTransactions(username: String, password: String, startDate: String, endDate: String) async throws -> [Transaction] {
        Self.generateTransactions()
    }

    func triggerRefresh(username: String, password: String) async throws {}

    func putTransferRules(username: String, password: String, rules: [TransferRule]) async throws {}

    func putVendors(username: String, password: String, vendors: [Vendor]) async throws {}

    private static var cachedTransactions: [Transaction]?

    private static func generateTransactions() -> [Transaction] {
        if let cached = cachedTransactions { return cached }
        let transactions = buildTransactions()
        cachedTransactions = transactions
        return transactions
    }

    private static func buildTransactions() -> [Transaction] {
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
        var transactions: [Transaction] = []
        var id = 1000

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

        let pendingDates: Set<String> = ["2026-03-20", "2026-03-19"]

        for date in dates {
            let count = [1, 1, 2, 2, 2, 3].randomElement()!
            for _ in 0..<count {
                let vendor = vendors.randomElement()!
                let amount = Double.random(in: vendor.amountRange)
                let amountStr = String(format: "%.2f", amount)
                let isPending = pendingDates.contains(date)
                id += 1
                transactions.append(Transaction(
                    lunchMoneyId: id,
                    date: date,
                    payee: vendor.payee,
                    amount: amountStr,
                    currency: "usd",
                    toBase: amount,
                    originalName: vendor.payee,
                    categoryName: vendor.category,
                    status: isPending ? "pending" : "cleared",
                    isIncome: false,
                    isPending: isPending,
                    excludeFromBudget: false,
                    excludeFromTotals: false,
                    createdAt: nowTs,
                    updatedAt: nowTs,
                    hasChildren: false,
                    isGroup: false,
                    plaidAccountId: vendor.accountId,
                    plaidAccountDisplayName: vendor.accountId == 1 ? "Chase Checking" : "Amex Gold",
                    source: "plaid",
                    displayName: vendor.payee,
                    accountDisplayName: vendor.accountId == 1 ? "Chase Checking" : "Amex Gold"
                ))
            }
        }

        for date in ["2026-03-15", "2026-03-01", "2026-02-15", "2026-02-01"] {
            id += 1
            transactions.append(Transaction(
                lunchMoneyId: id,
                date: date,
                payee: "Employer - Direct Deposit",
                amount: "3250.00",
                currency: "usd",
                toBase: 3250.00,
                notes: "Bi-weekly paycheck",
                originalName: "EMPLOYER DIRECT DEP",
                categoryName: "Income",
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
                recurringType: "cleared",
                recurringAmount: "3250.00",
                recurringCurrency: "usd",
                hasChildren: false,
                isGroup: false,
                plaidAccountId: 1,
                plaidAccountDisplayName: "Chase Checking",
                source: "plaid",
                displayName: "Employer - Direct Deposit",
                accountDisplayName: "Chase Checking"
            ))
        }

        return transactions
    }
}
