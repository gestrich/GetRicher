import FinanceCoreSDK
import Foundation

public struct WeeklyPaydownReport {
    /// Computes, per credit account, the period's Total Spend (sum-based, by type), Total Payments,
    /// and Payments Owed (balance-based). Card payments (payment-kind types) are excluded from spend
    /// and from every owed adjustment. The `transactions` array must include post-period rows
    /// (dated after `dateRange.end`, up to today) so the owed reconstruction can cancel them out —
    /// the same data the iOS view holds locally.
    public static func compute(
        accounts: [Account],
        transactions: [Transaction],
        types: [TransactionType] = [],
        dateRange: PaydownDateRange
    ) -> [AccountPaydownReport] {
        accounts
            .filter { $0.type == "credit" }
            .map { account in
                let accountTypes = types.filter { $0.targetAccountId == account.lunchMoneyId && !$0.isDeleted }

                let accountTx = transactions.filter { $0.plaidAccountId == account.lunchMoneyId && !$0.isIncome }
                let periodTx = accountTx.filter { $0.date >= dateRange.start && $0.date <= dateRange.end }
                let postPeriodPosted = accountTx.filter { $0.date > dateRange.end && !$0.isPending }

                func isPayment(_ tx: Transaction) -> Bool { TransactionClassifier.isPayment(tx, in: accountTypes) }

                // --- Total Spend: non-payment period transactions, bucketed by type ---
                let spendTx = periodTx.filter { !isPayment($0) }
                var byType: [UUID?: (type: TransactionType?, txs: [Transaction])] = [:]
                for tx in spendTx {
                    let type = TransactionClassifier.type(for: tx, in: accountTypes)
                    byType[type?.id, default: (type, [])].txs.append(tx)
                    byType[type?.id]?.type = type
                }
                let buckets: [SpendBucket] = byType.map { _, value in
                    SpendBucket(
                        typeId: value.type?.id,
                        typeName: value.type?.name ?? "Other Spend",
                        fundingAccountId: value.type?.fundingAccountId,
                        amount: value.txs.reduce(0.0) { $0 + $1.toBase },
                        count: value.txs.count
                    )
                }.sorted { abs($0.amount) > abs($1.amount) }
                let spend = WeeklySpend(buckets: buckets)

                // --- Total Payments: payment-kind period transactions ---
                let paymentTx = periodTx.filter { isPayment($0) }
                let payments = WeeklyPayments(
                    total: paymentTx.reduce(0.0) { $0 + abs($1.toBase) },
                    count: paymentTx.count
                )

                // --- Payments Owed: balance-based, payments excluded from adjustments ---
                let balance = Double(account.balance) ?? 0.0
                let pendingInPeriod = periodTx
                    .filter { $0.isPending && !isPayment($0) }
                    .reduce(0.0) { $0 + $1.toBase }
                let postedAfterPeriod = postPeriodPosted
                    .filter { !isPayment($0) }
                    .reduce(0.0) { $0 + $1.toBase }
                // Carve out in-period spend funded by other accounts (e.g. Cloud 9 → Reserve).
                var fundedTotals: [Int: Double] = [:]
                for tx in spendTx {
                    if let funding = TransactionClassifier.type(for: tx, in: accountTypes)?.fundingAccountId {
                        fundedTotals[funding, default: 0] += tx.toBase
                    }
                }
                let fundedByAccount = fundedTotals.map { accountId, amount in
                    FundingOwed(
                        fundingAccountId: accountId,
                        fundingAccountName: accounts.first { $0.lunchMoneyId == accountId }?.displayName ?? "Account \(accountId)",
                        amount: amount
                    )
                }.sorted { $0.fundingAccountName < $1.fundingAccountName }

                let owed = PaymentsOwed(
                    currentBalance: balance,
                    pendingInPeriod: pendingInPeriod,
                    postedAfterPeriod: postedAfterPeriod,
                    fundedByAccount: fundedByAccount
                )

                return AccountPaydownReport(
                    account: account,
                    periodStart: dateRange.start,
                    periodEnd: dateRange.end,
                    spend: spend,
                    payments: payments,
                    owed: owed
                )
            }
    }

    /// Convenience: compute for the current in-progress period using the pivot day.
    public static func computeCurrentPeriod(
        accounts: [Account],
        transactions: [Transaction],
        types: [TransactionType] = [],
        pivotDay: PivotDay,
        referenceDate: Date = Date()
    ) -> [AccountPaydownReport] {
        compute(
            accounts: accounts,
            transactions: transactions,
            types: types,
            dateRange: PaydownDateRange.computeCurrentPeriod(pivotDay: pivotDay, referenceDate: referenceDate)
        )
    }

    /// Push body: "PNC Core — Pay $X (+ $Y Reserve) · Spent $Z" per account.
    public static func notificationBody(from reports: [AccountPaydownReport]) -> String {
        reports.map { r in
            var owedPart = String(format: "Pay $%.2f", r.owed.owedFromPrimary)
            for f in r.owed.fundedByAccount {
                owedPart += String(format: " + $%.2f %@", f.amount, f.fundingAccountName)
            }
            let spentPart = String(format: "Spent $%.2f", r.spend.total)
            return "\(r.account.displayName) — \(owedPart) · \(spentPart)"
        }.joined(separator: " | ")
    }
}
