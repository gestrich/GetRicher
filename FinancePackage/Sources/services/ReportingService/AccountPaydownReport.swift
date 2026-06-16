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
    /// Informational only — the signed sum of in-period activity. NOT the amount to pay:
    /// in-period card payments make it go negative. Kept for diagnostics/charts.
    public var netPeriodSpending: Double {
        calculation.periodSpending - transferTotal
    }

    /// The canonical "amount to pay" for both the iOS view and the push notification:
    /// current balance + in-period pending − post-period posted charges − transfers.
    /// Single source of truth — every surface formats this value.
    public var netAdjustedSpending: Double {
        calculation.adjustedSpending - transferTotal
    }
}
