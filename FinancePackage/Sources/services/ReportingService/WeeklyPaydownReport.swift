import FinanceCoreSDK
import Foundation

public struct WeeklyPaydownReport {
    /// Computes a per-credit-account paydown for the given date range using charge-allocation:
    /// each in-period charge is bucketed to the funding account named by the user's transfer rules,
    /// card payments are excluded, and refunds net within their bucket. The amount to pay is the
    /// sum of the buckets — purely the period's spending, never reconstructed from the balance, so
    /// payments can't inflate it.
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
                let buckets = TransferBreakdown.compute(
                    accountId: account.lunchMoneyId,
                    periodTransactions: periodTx,
                    vendors: vendors,
                    rules: rules,
                    accounts: accounts
                )
                return AccountPaydownReport(
                    account: account,
                    buckets: buckets,
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

    /// Formats the canonical paydown for a push body: one segment per account, each listing its
    /// source buckets, e.g. "PNC Core — Reserve: $272.45, Payroll: $1,140.00".
    public static func notificationBody(from reports: [AccountPaydownReport]) -> String {
        reports
            .map { report in
                let parts = report.buckets.map { bucket in
                    "\(bucket.sourceAccountName): \(String(format: "$%.2f", bucket.amount))"
                }
                let detail = parts.isEmpty ? String(format: "$%.2f", report.amountToPay) : parts.joined(separator: ", ")
                return "\(report.account.displayName) — \(detail)"
            }
            .joined(separator: " | ")
    }
}
