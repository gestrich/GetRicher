import FinanceCoreSDK
import Foundation

public struct PaydownCalculation: Sendable {
    public let currentBalance: Double
    public let pendingAdjustment: Double
    public let postPeriodAdjustment: Double
    public let adjustedSpending: Double
    /// Sum of all transactions in the period (posted + pending), net of refunds.
    /// This is the direct measure of what was spent in the period.
    public let periodSpending: Double

    public init(
        currentBalance: Double,
        pendingAdjustment: Double,
        postPeriodAdjustment: Double,
        adjustedSpending: Double,
        periodSpending: Double
    ) {
        self.currentBalance = currentBalance
        self.pendingAdjustment = pendingAdjustment
        self.postPeriodAdjustment = postPeriodAdjustment
        self.adjustedSpending = adjustedSpending
        self.periodSpending = periodSpending
    }

    public static func compute(
        account: Account?,
        periodTransactions: [Transaction],
        postPeriodClearedTransactions: [Transaction]
    ) -> PaydownCalculation {
        let balance = account.flatMap { Double($0.balance) } ?? 0.0
        // Signed toBase (not abs): on a credit account a charge is positive and a refund/
        // payment is negative. Using signed amounts lets a refund correctly net out — e.g. a
        // post-period refund adds back to the cycle-end balance instead of being double-counted.
        let pendingTotal = periodTransactions
            .filter { $0.isPending }
            .reduce(0.0) { $0 + $1.toBase }
        let postPeriodTotal = postPeriodClearedTransactions
            .reduce(0.0) { $0 + $1.toBase }
        let adjusted = balance + pendingTotal - postPeriodTotal
        let periodSpending = periodTransactions.reduce(0.0) { $0 + $1.toBase }
        return PaydownCalculation(
            currentBalance: balance,
            pendingAdjustment: pendingTotal,
            postPeriodAdjustment: postPeriodTotal,
            adjustedSpending: adjusted,
            periodSpending: periodSpending
        )
    }
}
