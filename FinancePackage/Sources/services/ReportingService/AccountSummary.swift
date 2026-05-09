import FinanceCoreSDK
import Foundation

public struct AccountSnapshot: Sendable, Encodable {
    public let name: String
    public let type: String
    public let balance: Double
    public let currency: String

    public init(account: Account) {
        self.name = account.displayName
        self.type = account.type
        self.balance = Double(account.balance) ?? 0
        self.currency = account.currency
    }
}

public struct AccountSummary: Sendable, Encodable {
    public let accounts: [AccountSnapshot]
    public let totalsByType: [String: Double]

    public init(accounts: [Account]) {
        self.accounts = accounts.map(AccountSnapshot.init)
        var totals: [String: Double] = [:]
        for account in accounts {
            let balance = Double(account.balance) ?? 0
            totals[account.type, default: 0] += balance
        }
        self.totalsByType = totals
    }
}
