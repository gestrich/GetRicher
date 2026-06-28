import FinanceCoreSDK
import Foundation

/// A card's paydown for one period, expressed as per-source buckets: how much to transfer from
/// each funding account to cover that account's share of the period's charges. Card payments are
/// already excluded (they're settlements, not spending), so nothing here can be inflated by a
/// payment posting.
public struct AccountPaydownReport: Sendable {
    public let account: Account
    public let buckets: [TransferBreakdown]
    public let periodStart: String
    public let periodEnd: String

    public init(
        account: Account,
        buckets: [TransferBreakdown],
        periodStart: String,
        periodEnd: String
    ) {
        self.account = account
        self.buckets = buckets
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }

    /// Total to pay across all source buckets for the period.
    public var amountToPay: Double {
        buckets.reduce(0.0) { $0 + $1.amount }
    }
}
