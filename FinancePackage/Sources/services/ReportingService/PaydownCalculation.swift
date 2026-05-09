import FinanceCoreSDK
import Foundation

public struct PaydownCalculation: Sendable {
    public let currentBalance: Double
    public let pendingAdjustment: Double
    public let postPeriodAdjustment: Double
    public let adjustedSpending: Double

    public init(
        currentBalance: Double,
        pendingAdjustment: Double,
        postPeriodAdjustment: Double,
        adjustedSpending: Double
    ) {
        self.currentBalance = currentBalance
        self.pendingAdjustment = pendingAdjustment
        self.postPeriodAdjustment = postPeriodAdjustment
        self.adjustedSpending = adjustedSpending
    }

    public static func compute(
        account: Account?,
        periodTransactions: [Transaction],
        postPeriodClearedTransactions: [Transaction]
    ) -> PaydownCalculation {
        let balance = account.flatMap { Double($0.balance) } ?? 0.0
        let pendingTotal = periodTransactions
            .filter { $0.isPending }
            .reduce(0.0) { $0 + abs($1.toBase) }
        let postPeriodTotal = postPeriodClearedTransactions
            .reduce(0.0) { $0 + abs($1.toBase) }
        let adjusted = balance + pendingTotal - postPeriodTotal
        return PaydownCalculation(
            currentBalance: balance,
            pendingAdjustment: pendingTotal,
            postPeriodAdjustment: postPeriodTotal,
            adjustedSpending: adjusted
        )
    }
}
