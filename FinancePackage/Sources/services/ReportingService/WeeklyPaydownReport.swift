import FinanceCoreSDK
import Foundation

public struct WeeklyPaydownReport {
    public static func compute(
        accounts: [Account],
        transactions: [Transaction],
        pivotDay: PivotDay,
        referenceDate: Date = Date()
    ) -> [AccountPaydownReport] {
        let range = PaydownDateRange.compute(pivotDay: pivotDay, referenceDate: referenceDate)
        return compute(accounts: accounts, transactions: transactions, dateRange: range)
    }

    public static func compute(
        accounts: [Account],
        transactions: [Transaction],
        dateRange: PaydownDateRange
    ) -> [AccountPaydownReport] {
        accounts
            .filter { $0.type == "credit" }
            .map { account in
                let periodTx = transactions.filter { tx in
                    tx.plaidAccountId == account.lunchMoneyId &&
                        tx.date > dateRange.start &&
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
                return AccountPaydownReport(
                    account: account,
                    calculation: calculation,
                    periodStart: dateRange.start,
                    periodEnd: dateRange.end
                )
            }
    }

    public static func notificationBody(from reports: [AccountPaydownReport]) -> String {
        reports
            .map { report in
                let formatted = String(format: "$%.2f", report.calculation.adjustedSpending)
                return "\(report.account.displayName): \(formatted)"
            }
            .joined(separator: " | ")
    }
}
