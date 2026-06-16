import FinanceCoreSDK
import Foundation

public struct WeeklyPaydownReport {
    /// Unified entry point. Computes a per-credit-account paydown report for the given date range.
    /// `rules` and `vendors` are optional — when omitted, no bill-mapping subtraction is applied.
    /// Date filter convention: `tx.date >= range.start && tx.date <= range.end` (both inclusive).
    public static func compute(
        accounts: [Account],
        transactions: [Transaction],
        rules: [TransferRule] = [],
        vendors: [Vendor] = [],
        dateRange: PaydownDateRange
    ) -> [AccountPaydownReport] {
        accounts
            .filter { $0.type == "credit" }
            .map { account in
                let periodTx = transactions.filter { tx in
                    tx.plaidAccountId == account.lunchMoneyId &&
                        tx.date >= dateRange.start &&
                        tx.date <= dateRange.end &&
                        !tx.isIncome
                }
                let postPeriodTx = transactions.filter { tx in
                    tx.plaidAccountId == account.lunchMoneyId &&
                        tx.date > dateRange.end &&
                        !tx.isPending &&
                        !tx.isIncome
                }
                let calculation = PaydownCalculation.compute(
                    account: account,
                    periodTransactions: periodTx,
                    postPeriodClearedTransactions: postPeriodTx
                )
                let breakdown = TransferBreakdown.compute(
                    accountId: account.lunchMoneyId,
                    periodTransactions: periodTx,
                    vendors: vendors,
                    rules: rules,
                    accounts: accounts
                )
                return AccountPaydownReport(
                    account: account,
                    calculation: calculation,
                    transferBreakdown: breakdown,
                    periodStart: dateRange.start,
                    periodEnd: dateRange.end
                )
            }
    }

    /// Convenience: compute for the current in-progress period using the pivot day.
    public static func computeCurrentPeriod(
        accounts: [Account],
        transactions: [Transaction],
        rules: [TransferRule] = [],
        vendors: [Vendor] = [],
        pivotDay: PivotDay,
        referenceDate: Date = Date()
    ) -> [AccountPaydownReport] {
        let range = PaydownDateRange.computeCurrentPeriod(pivotDay: pivotDay, referenceDate: referenceDate)
        return compute(
            accounts: accounts,
            transactions: transactions,
            rules: rules,
            vendors: vendors,
            dateRange: range
        )
    }

    /// Formats the canonical "weekly paydown" value (`netAdjustedSpending`) per credit account.
    /// Used for push notification bodies. This is the balance-based amount to pay
    /// (balance + in-period pending − post-period posted − transfers), the same value
    /// the iOS Weekly Paydown view shows as "Amount to Pay".
    public static func notificationBody(from reports: [AccountPaydownReport]) -> String {
        reports
            .map { report in
                let formatted = String(format: "$%.2f", report.netAdjustedSpending)
                return "\(report.account.displayName): \(formatted)"
            }
            .joined(separator: " | ")
    }
}
