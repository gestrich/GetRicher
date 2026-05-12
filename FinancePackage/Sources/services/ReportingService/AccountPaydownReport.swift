import FinanceCoreSDK
import Foundation

public struct AccountPaydownReport: Sendable {
    public let account: Account
    public let calculation: PaydownCalculation
    public let transferBreakdown: [TransferBreakdown]
    public let periodStart: String
    public let periodEnd: String

    public init(
        account: Account,
        calculation: PaydownCalculation,
        transferBreakdown: [TransferBreakdown] = [],
        periodStart: String,
        periodEnd: String
    ) {
        self.account = account
        self.calculation = calculation
        self.transferBreakdown = transferBreakdown
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }

    /// Sum of transfer-rule matched amounts (bills covered by other accounts).
    public var transferTotal: Double {
        transferBreakdown.reduce(0.0) { $0 + $1.amount }
    }

    /// Period spending (posted + pending in the period) net of bill mappings.
    /// This is the canonical "weekly paydown" value for both the iOS view and the push notification.
    public var netPeriodSpending: Double {
        calculation.periodSpending - transferTotal
    }

    /// Balance-based pay-down amount net of bill mappings (used for completed periods).
    public var netAdjustedSpending: Double {
        calculation.adjustedSpending - transferTotal
    }
}
