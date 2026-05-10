import FinanceCoreSDK
import Foundation

public struct AccountPaydownReport: Sendable {
    public let account: Account
    public let calculation: PaydownCalculation
    public let periodStart: String
    public let periodEnd: String

    public init(
        account: Account,
        calculation: PaydownCalculation,
        periodStart: String,
        periodEnd: String
    ) {
        self.account = account
        self.calculation = calculation
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }
}
