import FinanceCoreSDK
import Foundation

/// A credit card's full paydown for one period: the two calculations (sum-based Total Spend and
/// balance-based Payments Owed) plus Total Payments, kept as separate concepts.
public struct AccountPaydownReport: Sendable {
    public let account: Account
    public let periodStart: String
    public let periodEnd: String
    public let spend: WeeklySpend
    public let payments: WeeklyPayments
    public let owed: PaymentsOwed

    public init(
        account: Account,
        periodStart: String,
        periodEnd: String,
        spend: WeeklySpend,
        payments: WeeklyPayments,
        owed: PaymentsOwed
    ) {
        self.account = account
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.spend = spend
        self.payments = payments
        self.owed = owed
    }
}
