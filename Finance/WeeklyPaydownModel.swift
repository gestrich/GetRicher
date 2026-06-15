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
        let oldSelected = selectedPeriod
        // 1 in-progress (current) period + 10 completed prior weeks
        let periods = BudgetPeriod.periods(count: 11, pivotDay: pivotDay)
        budgetPeriods = periods

        let inProgressPeriod = periods.first

        guard let oldSelected else {
            selectedPeriod = inProgressPeriod
            return
        }

        if oldSelected == inProgressPeriod {
            // Selection was tracking the live period — keep tracking it
            selectedPeriod = inProgressPeriod
        } else if let match = periods.first(where: { $0 == oldSelected }) {
            // The previously-selected period still exists — stay on it
            selectedPeriod = match
        } else {
            // Selected period fell out of range
            selectedPeriod = inProgressPeriod
        }
    }

    func account(id accountId: Int?, from accounts: [Account]) -> Account? {
        guard let accountId = accountId else { return nil }
        return accounts.first { $0.lunchMoneyId == accountId }
    }

    var dateRange: PaydownDateRange {
        guard let period = selectedPeriod else {
            return PaydownDateRange.computeCurrentPeriod(pivotDay: pivotDay)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return PaydownDateRange(
            start: formatter.string(from: period.start),
            end: formatter.string(from: period.end)
        )
    }

    /// Full per-account paydown report for the selected account/period, including transfer breakdown.
    /// This is the shared algorithm — the same call the Lambda uses.
    func report(
        accountId: Int?,
        accounts: [Account],
        transactions: [Transaction],
        rules: [TransferRule],
        vendors: [Vendor]
    ) -> AccountPaydownReport? {
        guard let accountId else { return nil }
        let reports = WeeklyPaydownReport.compute(
            accounts: accounts,
            transactions: transactions,
            rules: rules,
            vendors: vendors,
            dateRange: dateRange
        )
        return reports.first { $0.account.lunchMoneyId == accountId }
    }
}
