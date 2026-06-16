import Testing
@testable import ReportingService
import FinanceCoreSDK
import Foundation

// MARK: - Helpers

private func makeAccount(id: Int = 1, type: String = "credit", balance: String = "1000.00") -> Account {
    Account(
        lunchMoneyId: id,
        name: "Acct\(id)",
        displayName: "Account \(id)",
        type: type,
        subtype: "checking",
        mask: "000\(id)",
        institutionName: "Bank",
        status: "active",
        balance: balance,
        currency: "usd"
    )
}

private func makeTransaction(
    id: Int = 1,
    payee: String = "Vendor",
    isPending: Bool = false,
    toBase: Double = 100.0
) -> Transaction {
    Transaction(
        lunchMoneyId: id,
        date: "2026-05-01",
        payee: payee,
        amount: "100.00",
        currency: "usd",
        toBase: toBase,
        originalName: payee,
        status: isPending ? "pending" : "cleared",
        isIncome: false,
        isPending: isPending,
        excludeFromBudget: false,
        excludeFromTotals: false,
        createdAt: "2026-05-01",
        updatedAt: "2026-05-01",
        hasChildren: false,
        isGroup: false
    )
}

// May 4, 2026 is a Monday (weekday 2 in Calendar.current where 1 = Sunday)
private func knownMonday() -> Date {
    var c = DateComponents()
    c.year = 2026; c.month = 5; c.day = 4
    return Calendar.current.date(from: c)!
}

// MARK: - BudgetPeriod
// Pivot day is the FIRST day of its period. Filter convention: tx.date >= start && tx.date <= end.

@Suite struct BudgetPeriodTests {
    @Test("periods returns requested count")
    func periodsCount() {
        let periods = BudgetPeriod.periods(count: 4, pivotDay: .monday, referenceDate: knownMonday())
        #expect(periods.count == 4)
    }

    @Test("first period starts on the pivot weekday")
    func periodsPivotAlignment() {
        let periods = BudgetPeriod.periods(count: 1, pivotDay: .monday, referenceDate: knownMonday())
        let weekday = Calendar.current.component(.weekday, from: periods[0].start)
        #expect(weekday == PivotDay.monday.weekdayNumber)
    }

    @Test("current in-progress period ends on the reference date and starts at the pivot")
    func periodsCurrentPeriodEndsOnReferenceDate() {
        let monday = knownMonday()
        let periods = BudgetPeriod.periods(count: 1, pivotDay: .monday, referenceDate: monday)
        let expectedEnd = Calendar.current.startOfDay(for: monday)
        #expect(Calendar.current.isDate(periods[0].end, inSameDayAs: expectedEnd))
        #expect(Calendar.current.isDate(periods[0].start, inSameDayAs: expectedEnd))
    }

    @Test("consecutive periods are adjacent: period[N].end is the day before period[N-1].start")
    func periodsAdjacency() {
        let periods = BudgetPeriod.periods(count: 3, pivotDay: .monday, referenceDate: knownMonday())
        #expect(periods.count == 3)
        let dayBeforeP0Start = Calendar.current.date(byAdding: .day, value: -1, to: periods[0].start)!
        #expect(Calendar.current.isDate(periods[1].end, inSameDayAs: dayBeforeP0Start))
        let dayBeforeP1Start = Calendar.current.date(byAdding: .day, value: -1, to: periods[1].start)!
        #expect(Calendar.current.isDate(periods[2].end, inSameDayAs: dayBeforeP1Start))
    }

    @Test("completed periods span exactly 7 days")
    func periodsCompletedLength() {
        let periods = BudgetPeriod.periods(count: 3, pivotDay: .monday, referenceDate: knownMonday())
        let diff = Calendar.current.dateComponents([.day], from: periods[1].start, to: periods[1].end).day!
        #expect(diff == 6) // 7 days inclusive of both ends
    }

    @Test("startString and endString use yyyy-MM-dd format")
    func periodsStringFormat() {
        // knownMonday is 2026-05-04; with Monday pivot, current period both starts and ends on 5/4
        let periods = BudgetPeriod.periods(count: 1, pivotDay: .monday, referenceDate: knownMonday())
        #expect(periods[0].startString == "2026-05-04")
        #expect(periods[0].endString == "2026-05-04")
    }
}

// MARK: - PaydownDateRange

@Suite struct PaydownDateRangeTests {
    @Test("compute returns the previous completed week (7 days, inclusive)")
    func computeOnPivotDay() {
        // ref = Mon 2026-05-04, pivot = Monday. Prior completed period: 4/27 → 5/3.
        let range = PaydownDateRange.compute(pivotDay: .monday, referenceDate: knownMonday())
        #expect(range.start == "2026-04-27")
        #expect(range.end == "2026-05-03")
    }

    @Test("compute rolls back to the most recent pivot before computing the prior period")
    func computeRollsBackToPivot() {
        // May 6, 2026 is a Wednesday; most recent Monday is May 4. Prior period: 4/27 → 5/3.
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 6
        let wednesday = Calendar.current.date(from: c)!
        let range = PaydownDateRange.compute(pivotDay: .monday, referenceDate: wednesday)
        #expect(range.start == "2026-04-27")
        #expect(range.end == "2026-05-03")
    }

    @Test("computeCurrentPeriod spans most recent pivot through today (inclusive)")
    func computeCurrentPeriod() {
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 6
        let wednesday = Calendar.current.date(from: c)!
        let range = PaydownDateRange.computeCurrentPeriod(pivotDay: .monday, referenceDate: wednesday)
        #expect(range.start == "2026-05-04")
        #expect(range.end == "2026-05-06")
    }
}

// MARK: - PaydownCalculation

@Suite struct PaydownCalculationTests {
    @Test("nil account produces all-zero result")
    func computeNilAccount() {
        let result = PaydownCalculation.compute(
            account: nil,
            periodTransactions: [],
            postPeriodClearedTransactions: []
        )
        #expect(result.currentBalance == 0)
        #expect(result.pendingAdjustment == 0)
        #expect(result.postPeriodAdjustment == 0)
        #expect(result.adjustedSpending == 0)
    }

    @Test("account balance is reflected with no transactions")
    func computeBalanceOnly() {
        let result = PaydownCalculation.compute(
            account: makeAccount(balance: "750.00"),
            periodTransactions: [],
            postPeriodClearedTransactions: []
        )
        #expect(result.currentBalance == 750.0)
        #expect(result.adjustedSpending == 750.0)
    }

    @Test("pending period transactions are added to the adjustment")
    func computePendingAdjustment() {
        let pending = [
            makeTransaction(id: 1, isPending: true, toBase: 50.0),
            makeTransaction(id: 2, isPending: true, toBase: 30.0)
        ]
        let result = PaydownCalculation.compute(
            account: makeAccount(balance: "1000.00"),
            periodTransactions: pending,
            postPeriodClearedTransactions: []
        )
        #expect(result.pendingAdjustment == 80.0)
        #expect(result.adjustedSpending == 1080.0)
    }

    @Test("post-period cleared transactions are subtracted from adjusted spending")
    func computePostPeriodAdjustment() {
        let postPeriod = [makeTransaction(id: 1, isPending: false, toBase: 200.0)]
        let result = PaydownCalculation.compute(
            account: makeAccount(balance: "1000.00"),
            periodTransactions: [],
            postPeriodClearedTransactions: postPeriod
        )
        #expect(result.postPeriodAdjustment == 200.0)
        #expect(result.adjustedSpending == 800.0)
    }

    @Test("post-period refunds net out (signed, not abs)")
    func computePostPeriodRefundNetsOut() {
        // A $100 charge and a $30 refund posted after the period. Signed total is $70, so the
        // cycle-end balance is balance − 70. Using abs would wrongly subtract 130.
        let postPeriod = [
            makeTransaction(id: 1, isPending: false, toBase: 100.0),
            makeTransaction(id: 2, isPending: false, toBase: -30.0)
        ]
        let result = PaydownCalculation.compute(
            account: makeAccount(balance: "1000.00"),
            periodTransactions: [],
            postPeriodClearedTransactions: postPeriod
        )
        #expect(result.postPeriodAdjustment == 70.0)
        #expect(result.adjustedSpending == 930.0)
    }

    @Test("non-pending period transactions are excluded from pending adjustment")
    func computeNonPendingExcluded() {
        let cleared = [makeTransaction(id: 1, isPending: false, toBase: 100.0)]
        let result = PaydownCalculation.compute(
            account: makeAccount(balance: "1000.00"),
            periodTransactions: cleared,
            postPeriodClearedTransactions: []
        )
        #expect(result.pendingAdjustment == 0)
        #expect(result.adjustedSpending == 1000.0)
    }
}

// MARK: - TransferBreakdown

@Suite struct TransferBreakdownTests {
    @Test("returns empty when no rules target the account")
    func computeNoMatchingRules() {
        let result = TransferBreakdown.compute(
            accountId: 99,
            periodTransactions: [makeTransaction()],
            vendors: [], rules: [], accounts: []
        )
        #expect(result.isEmpty)
    }

    @Test("matches transactions to a named vendor rule")
    func computeVendorRuleMatch() {
        let vendor = Vendor(name: "Amazon", filterText: "amazon")
        let rule = TransferRule(
            name: "Shopping", vendor: vendor,
            sourceAccountId: 10, targetAccountId: 1, priority: 1
        )
        let tx = makeTransaction(id: 1, payee: "Amazon Prime", toBase: 120.0)
        let sourceAccount = makeAccount(id: 10, type: "depository", balance: "500.00")

        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: [tx],
            vendors: [vendor],
            rules: [rule],
            accounts: [sourceAccount]
        )

        #expect(result.count == 1)
        #expect(result[0].ruleName == "Shopping")
        #expect(result[0].amount == 120.0)
        #expect(result[0].transactionCount == 1)
        #expect(result[0].sourceAccountName == "Account 10")
    }

    @Test("routes unmatched transactions to the default nil-vendor rule")
    func computeDefaultRule() {
        let rule = TransferRule(
            name: "Other", vendor: nil,
            sourceAccountId: nil, targetAccountId: 1, priority: 0
        )
        let tx = makeTransaction(id: 1, payee: "Unknown Vendor", toBase: 75.0)

        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: [tx],
            vendors: [], rules: [rule], accounts: []
        )

        #expect(result.count == 1)
        #expect(result[0].ruleName == "Other")
        #expect(result[0].amount == 75.0)
        #expect(result[0].sourceAccountName == "Unspecified")
    }

    @Test("sums amounts for multiple transactions matched by same rule")
    func computeMultipleTransactionsSummed() {
        let vendor = Vendor(name: "Starbucks", filterText: "starbucks")
        let rule = TransferRule(
            name: "Coffee", vendor: vendor,
            sourceAccountId: nil, targetAccountId: 1, priority: 1
        )
        let txs = [
            makeTransaction(id: 1, payee: "Starbucks #1", toBase: 5.0),
            makeTransaction(id: 2, payee: "Starbucks #2", toBase: 6.5)
        ]

        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: txs,
            vendors: [vendor],
            rules: [rule],
            accounts: []
        )

        #expect(result.count == 1)
        #expect(result[0].amount == 11.5)
        #expect(result[0].transactionCount == 2)
    }
}

// MARK: - User's hand-calculated paydown (balance-based method)
//
// Reproduces Bill's manual calculation for the completed week (cycle ending 6/12/2026)
// on PNC Core - Spending. His method:
//   1. Start from the current balance.
//   2. Subtract charges that POSTED after the cycle period (6/13, 6/14, 6/15) — they
//      are already baked into the balance but belong to next week.
//   3. Add pending charges that occurred DURING the cycle (not yet in the balance). [none this week]
//   4. Subtract special charges covered by transfers from other accounts
//      (Cloud 9 Aviation, paid from PNC Six Month Reserve).
//
//   2417.33 − 36.45 − 10.55 − 60 − 240.79 − 535 − 6.99 − 49.99 − 49.99 − 197.30 − 267.31 = 962.96
//
// This is exactly `AccountPaydownReport.netAdjustedSpending`
// (= adjustedSpending − transferTotal = balance + pending − postPeriod − transfers).
// The current UI/notification instead surface `netPeriodSpending` (the signed sum of
// in-period debits and credits), which is the value Bill saw as -1047.80 — wrong because
// in-period card *payments* drag it negative.

@Suite struct UserHandCalcPaydownTests {
    private let coreAccountId = 344066
    private let reserveAccountId = 344059

    // Charges the user subtracted because they posted AFTER the cycle (6/13–6/15).
    private let postPeriodPostedCharges: [Double] = [36.45, 10.55, 60, 240.79, 535, 6.99, 49.99, 49.99]
    // Cloud 9 charges inside the cycle, covered by a transfer from Six Month Reserve.
    private let cloud9InPeriod: [Double] = [267.31, 197.30] // 6/6 and 6/9

    private func coreAccount() -> Account {
        Account(
            lunchMoneyId: coreAccountId,
            name: "PNC Core - Spending",
            displayName: "PNC PNC Core - Spending",
            type: "credit",
            subtype: "credit card",
            mask: "4705",
            institutionName: "PNC",
            status: "active",
            balance: "2417.33",
            currency: "usd"
        )
    }

    private func cloud9Rule() -> (TransferRule, Vendor) {
        let vendor = Vendor(name: "Cloud 9 Aviation", filterText: "cloud 9")
        let rule = TransferRule(
            name: "Cloud 9 Reserve",
            vendor: vendor,
            sourceAccountId: reserveAccountId,
            targetAccountId: coreAccountId,
            priority: 1
        )
        return (rule, vendor)
    }

    @Test("balance-based net paydown reproduces Bill's hand calc of 962.96")
    func reproducesHandCalc() {
        let account = coreAccount()
        let (rule, vendor) = cloud9Rule()
        let reserve = makeAccount(id: reserveAccountId, type: "depository", balance: "77254.73")

        // In-period transactions: just the two Cloud 9 charges (the transfer-covered ones).
        // (Other in-period spending is already reflected in the balance and not pending,
        //  so it does not affect the balance-based formula.)
        var id = 1
        let periodTx: [Transaction] = cloud9InPeriod.map { amt in
            defer { id += 1 }
            return makeTransaction(id: id, payee: "Cloud 9 Aviation", isPending: false, toBase: amt)
        }

        // Post-period POSTED charges (6/13–6/15) — subtracted from the balance.
        let postPeriodTx: [Transaction] = postPeriodPostedCharges.map { amt in
            defer { id += 1 }
            return makeTransaction(id: id, payee: "Post-period charge", isPending: false, toBase: amt)
        }

        let calculation = PaydownCalculation.compute(
            account: account,
            periodTransactions: periodTx,
            postPeriodClearedTransactions: postPeriodTx
        )
        let breakdown = TransferBreakdown.compute(
            accountId: coreAccountId,
            periodTransactions: periodTx,
            vendors: [vendor],
            rules: [rule],
            accounts: [account, reserve]
        )
        let report = AccountPaydownReport(
            account: account,
            calculation: calculation,
            transferBreakdown: breakdown,
            periodStart: "2026-06-06",
            periodEnd: "2026-06-12"
        )

        // Transfer covers exactly the two Cloud 9 charges.
        #expect(report.transferTotal == 464.61)
        // balance(2417.33) − postPeriod(989.76) + pending(0) = 1427.57
        #expect((calculation.adjustedSpending - 1427.57).magnitude < 0.005)
        // Final amount Bill pays on PNC Core.
        #expect((report.netAdjustedSpending - 962.96).magnitude < 0.005)

        // The shared notification formatter surfaces this same balance-based value
        // (not the signed period sum) — the canonical "amount to pay".
        let body = WeeklyPaydownReport.notificationBody(from: [report])
        #expect(body.contains("$962.96"))
    }
}

// MARK: - AccountSummary

@Suite struct AccountSummaryTests {
    @Test("empty account list produces empty summary")
    func emptyAccounts() {
        let summary = AccountSummary(accounts: [])
        #expect(summary.accounts.isEmpty)
        #expect(summary.totalsByType.isEmpty)
    }

    @Test("accounts of the same type are summed in totalsByType")
    func sameTypeSummed() {
        let accounts = [
            makeAccount(id: 1, type: "credit", balance: "500.00"),
            makeAccount(id: 2, type: "credit", balance: "300.00")
        ]
        let summary = AccountSummary(accounts: accounts)
        #expect(summary.totalsByType["credit"] == 800.0)
    }

    @Test("accounts of different types populate separate buckets")
    func differentTypesAreSeparate() {
        let accounts = [
            makeAccount(id: 1, type: "depository", balance: "1000.00"),
            makeAccount(id: 2, type: "credit", balance: "500.00")
        ]
        let summary = AccountSummary(accounts: accounts)
        #expect(summary.totalsByType["depository"] == 1000.0)
        #expect(summary.totalsByType["credit"] == 500.0)
    }

    @Test("account snapshots reflect name, balance, and type")
    func accountSnapshotFields() {
        let summary = AccountSummary(accounts: [makeAccount(id: 1, type: "credit", balance: "250.50")])
        #expect(summary.accounts.count == 1)
        #expect(summary.accounts[0].name == "Account 1")
        #expect(summary.accounts[0].balance == 250.5)
        #expect(summary.accounts[0].type == "credit")
    }
}
