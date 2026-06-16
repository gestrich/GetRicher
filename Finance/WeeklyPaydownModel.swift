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
        // periods[0] = in-progress week, periods[1] = last completed week, then older weeks.
        let periods = BudgetPeriod.periods(count: 11, pivotDay: pivotDay)
        budgetPeriods = periods

        // The weekly paydown is what you pay for the week that just ended, so default to the
        // last completed week — the same period the server notification/report computes.
        let defaultPeriod = periods.count > 1 ? periods[1] : periods.first

        guard let oldSelected else {
            selectedPeriod = defaultPeriod
            return
        }

        if let match = periods.first(where: { $0 == oldSelected }) {
            // The previously-selected period still exists — stay on it.
            selectedPeriod = match
        } else {
            // Selection fell out of range — fall back to the last completed week.
            selectedPeriod = defaultPeriod
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
