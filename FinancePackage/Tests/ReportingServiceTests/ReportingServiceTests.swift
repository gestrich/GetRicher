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

    @Test("first period ends on the reference date")
    func periodsCurrentPeriodEndsOnReferenceDate() {
        let monday = knownMonday()
        let periods = BudgetPeriod.periods(count: 1, pivotDay: .monday, referenceDate: monday)
        let expectedEnd = Calendar.current.startOfDay(for: monday)
        #expect(Calendar.current.isDate(periods[0].end, inSameDayAs: expectedEnd))
    }

    @Test("consecutive periods are adjacent with no gap")
    func periodsAdjacency() {
        let periods = BudgetPeriod.periods(count: 3, pivotDay: .monday, referenceDate: knownMonday())
        #expect(periods.count == 3)
        let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: periods[0].start)!
        #expect(Calendar.current.isDate(periods[1].end, inSameDayAs: dayBefore))
    }

    @Test("startString and endString use yyyy-MM-dd format")
    func periodsStringFormat() {
        // knownMonday is 2026-05-04; with Monday pivot, period starts and ends on that same day
        let periods = BudgetPeriod.periods(count: 1, pivotDay: .monday, referenceDate: knownMonday())
        #expect(periods[0].startString == "2026-05-04")
        #expect(periods[0].endString == "2026-05-04")
    }
}

// MARK: - PaydownDateRange

@Suite struct PaydownDateRangeTests {
    @Test("ends on pivot day when reference is the pivot day")
    func computeOnPivotDay() {
        let range = PaydownDateRange.compute(pivotDay: .monday, referenceDate: knownMonday())
        #expect(range.end == "2026-05-04")
        #expect(range.start == "2026-04-27")
    }

    @Test("rolls back to most recent pivot when reference is not the pivot day")
    func computeRollsBackToPivot() {
        // May 6, 2026 is a Wednesday; most recent Monday is May 4
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 6
        let wednesday = Calendar.current.date(from: c)!
        let range = PaydownDateRange.compute(pivotDay: .monday, referenceDate: wednesday)
        #expect(range.end == "2026-05-04")
        #expect(range.start == "2026-04-27")
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
