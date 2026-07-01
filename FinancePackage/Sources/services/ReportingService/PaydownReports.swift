import FinanceCoreSDK
import Foundation

// MARK: - Total Spend

/// One type's slice of a period's spending (charges net of refunds). `typeId` is nil for "Other Spend".
public struct SpendBucket: Identifiable, Sendable {
    public let id: UUID
    public let typeId: UUID?
    public let typeName: String
    public let fundingAccountId: Int?
    public let amount: Double
    public let count: Int
    /// lunchMoneyIds of the transactions in this bucket (for drill-down traceability).
    public let transactionIds: [Int]

    public init(id: UUID = UUID(), typeId: UUID?, typeName: String, fundingAccountId: Int?, amount: Double, count: Int, transactionIds: [Int] = []) {
        self.id = id
        self.typeId = typeId
        self.typeName = typeName
        self.fundingAccountId = fundingAccountId
        self.amount = amount
        self.count = count
        self.transactionIds = transactionIds
    }
}

/// Total Spend for the period: all non-payment transactions, bucketed by type.
public struct WeeklySpend: Sendable {
    public let buckets: [SpendBucket]
    public init(buckets: [SpendBucket]) { self.buckets = buckets }
    public var total: Double { buckets.reduce(0.0) { $0 + $1.amount } }
}

// MARK: - Total Payments

/// Total Payments for the period: the settlements that paid the card down.
public struct WeeklyPayments: Sendable {
    public let total: Double // positive amount paid
    public let count: Int
    public let transactionIds: [Int]
    public init(total: Double, count: Int, transactionIds: [Int] = []) {
        self.total = total; self.count = count; self.transactionIds = transactionIds
    }
}

// MARK: - Payments Owed

/// Amount owed from a specific funding account (e.g. Cloud 9 charges paid from Reserve).
public struct FundingOwed: Identifiable, Sendable {
    public let id: UUID
    public let fundingAccountId: Int
    public let fundingAccountName: String
    public let amount: Double
    public let transactionIds: [Int]

    public init(id: UUID = UUID(), fundingAccountId: Int, fundingAccountName: String, amount: Double, transactionIds: [Int] = []) {
        self.id = id
        self.fundingAccountId = fundingAccountId
        self.fundingAccountName = fundingAccountName
        self.amount = amount
        self.transactionIds = transactionIds
    }
}

/// Balance-based amount to pay. Payments are excluded from every adjustment — they only live in
/// `currentBalance`, where they already reduce what's owed.
public struct PaymentsOwed: Sendable {
    public let currentBalance: Double
    /// Signed sum of in-period pending (not-yet-posted), non-payment transactions.
    public let pendingInPeriod: Double
    /// Signed sum of post-period posted, non-payment transactions.
    public let postedAfterPeriod: Double
    /// balance + pendingInPeriod − postedAfterPeriod (across all funding sources).
    public let owedTotal: Double
    /// Spend carved out to other accounts (Cloud 9 → Reserve).
    public let fundedByAccount: [FundingOwed]
    /// owedTotal − Σ fundedByAccount — what you pay from your primary account.
    public let owedFromPrimary: Double
    /// Contributing transaction lunchMoneyIds for drill-down traceability.
    public let pendingTransactionIds: [Int]
    public let postedAfterTransactionIds: [Int]

    public init(
        currentBalance: Double,
        pendingInPeriod: Double,
        postedAfterPeriod: Double,
        fundedByAccount: [FundingOwed],
        pendingTransactionIds: [Int] = [],
        postedAfterTransactionIds: [Int] = []
    ) {
        self.currentBalance = currentBalance
        self.pendingInPeriod = pendingInPeriod
        self.postedAfterPeriod = postedAfterPeriod
        self.owedTotal = currentBalance + pendingInPeriod - postedAfterPeriod
        self.fundedByAccount = fundedByAccount
        self.owedFromPrimary = (currentBalance + pendingInPeriod - postedAfterPeriod)
            - fundedByAccount.reduce(0.0) { $0 + $1.amount }
        self.pendingTransactionIds = pendingTransactionIds
        self.postedAfterTransactionIds = postedAfterTransactionIds
    }
}
