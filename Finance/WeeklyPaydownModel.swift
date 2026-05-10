import FinanceCoreSDK
import Foundation
import ReportingService

@MainActor @Observable
class WeeklyPaydownModel {

    var pivotDay: PivotDay = .saturday {
        didSet { refreshPeriods() }
    }
    var budgetPeriods: [BudgetPeriod] = []
    var selectedPeriod: BudgetPeriod?

    init() {
        refreshPeriods()
    }

    func refreshPeriods() {
        let periods = BudgetPeriod.periods(count: 11, pivotDay: pivotDay)
        budgetPeriods = periods
        selectedPeriod = periods.count > 1 ? periods[1] : periods.first
    }

    func account(id accountId: Int?, from accounts: [Account]) -> Account? {
        guard let accountId = accountId else { return nil }
        return accounts.first { $0.lunchMoneyId == accountId }
    }

    var dateRange: PaydownDateRange {
        guard let period = selectedPeriod else {
            return PaydownDateRange.compute(pivotDay: pivotDay)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return PaydownDateRange(
            start: formatter.string(from: period.start),
            end: formatter.string(from: period.end)
        )
    }

    func calculation(
        accountId: Int?,
        accounts: [Account],
        transactions: [Transaction]
    ) -> PaydownCalculation {
        let reports = WeeklyPaydownReport.compute(
            accounts: accounts,
            transactions: transactions,
            dateRange: dateRange
        )
        if let accountId, let report = reports.first(where: { $0.account.lunchMoneyId == accountId }) {
            return report.calculation
        }
        return PaydownCalculation.compute(account: nil, periodTransactions: [], postPeriodClearedTransactions: [])
    }

    func transferBreakdown(
        accountId: Int,
        periodTransactions: [Transaction],
        vendors: [Vendor],
        rules: [TransferRule],
        accounts: [Account]
    ) -> [TransferBreakdown] {
        TransferBreakdown.compute(
            accountId: accountId,
            periodTransactions: periodTransactions,
            vendors: vendors,
            rules: rules,
            accounts: accounts
        )
    }
}
