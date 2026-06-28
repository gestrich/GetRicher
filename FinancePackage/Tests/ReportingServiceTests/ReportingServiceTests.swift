import Testing
@testable import ReportingService
import FinanceCoreSDK
import Foundation

// MARK: - Helpers

private extension Double {
    func isApprox(_ other: Double, tol: Double = 0.005) -> Bool { (self - other).magnitude < tol }
}

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
    toBase: Double = 100.0,
    date: String = "2026-05-01",
    plaidAccountId: Int? = nil,
    isIncome: Bool = false
) -> Transaction {
    Transaction(
        lunchMoneyId: id,
        date: date,
        payee: payee,
        amount: "100.00",
        currency: "usd",
        toBase: toBase,
        originalName: payee,
        status: isPending ? "pending" : "cleared",
        isIncome: isIncome,
        isPending: isPending,
        excludeFromBudget: false,
        excludeFromTotals: false,
        createdAt: "2026-05-01",
        updatedAt: "2026-05-01",
        hasChildren: false,
        isGroup: false,
        plaidAccountId: plaidAccountId
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

// MARK: - TransferBreakdown (per-source charge allocation)

@Suite struct TransferBreakdownTests {
    @Test("no rules: all charges fall into one Unspecified bucket")
    func computeNoMatchingRules() {
        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: [makeTransaction(toBase: 50)],
            vendors: [], rules: [], accounts: []
        )
        #expect(result.count == 1)
        #expect(result[0].sourceAccountName == "Unspecified")
        #expect(result[0].amount == 50)
    }

    @Test("matches transactions to a named vendor rule's source bucket")
    func computeVendorRuleMatch() {
        let vendor = Vendor(name: "Amazon", filterText: "amazon")
        let rule = TransferRule(name: "Shopping", vendor: vendor, sourceAccountId: 10, targetAccountId: 1, priority: 1)
        let tx = makeTransaction(id: 1, payee: "Amazon Prime", toBase: 120.0)
        let sourceAccount = makeAccount(id: 10, type: "depository", balance: "500.00")

        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: [tx],
            vendors: [vendor], rules: [rule], accounts: [sourceAccount]
        )

        #expect(result.count == 1)
        #expect(result[0].ruleName == "Shopping")
        #expect(result[0].amount == 120.0)
        #expect(result[0].sourceAccountName == "Account 10")
    }

    @Test("vendor-matched charges and the rest split into separate source buckets")
    func computeVendorAndDefaultSplit() {
        let cloud9 = Vendor(name: "Cloud 9", filterText: "cloud 9")
        let cloud9Rule = TransferRule(name: "Cloud 9 → Reserve", vendor: cloud9, sourceAccountId: 10, targetAccountId: 1, priority: 1)
        let defaultRule = TransferRule(name: "Everything Else → Payroll", vendor: nil, sourceAccountId: 20, targetAccountId: 1, priority: 0)
        let reserve = makeAccount(id: 10, type: "depository")
        let payroll = makeAccount(id: 20, type: "depository")
        let txs = [
            makeTransaction(id: 1, payee: "Cloud 9 Aviation", toBase: 200),
            makeTransaction(id: 2, payee: "Target", toBase: 60),
            makeTransaction(id: 3, payee: "Walmart", toBase: 40),
        ]

        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: txs,
            vendors: [cloud9], rules: [cloud9Rule, defaultRule], accounts: [reserve, payroll]
        )

        #expect(result.count == 2)
        let cloud9Bucket = result.first { $0.ruleName == "Cloud 9 → Reserve" }
        let defaultBucket = result.first { $0.ruleName == "Everything Else → Payroll" }
        #expect(cloud9Bucket?.amount == 200)
        #expect(defaultBucket?.amount == 100) // 60 + 40
    }

    @Test("payment-kind rule excludes card payments from every bucket")
    func computePaymentExclusion() {
        let payVendor = Vendor(name: "PNC Payment", filterText: "THANK YOU FOR YOUR PMT")
        let paymentRule = TransferRule(name: "PNC Payment", vendor: payVendor, targetAccountId: 1, kind: .payment)
        let defaultRule = TransferRule(name: "Default", vendor: nil, sourceAccountId: 20, targetAccountId: 1)
        let payroll = makeAccount(id: 20, type: "depository")
        let txs = [
            makeTransaction(id: 1, payee: "Target", toBase: 100),
            makeTransaction(id: 2, payee: "THANK YOU FOR YOUR PMT 06/20 XXXX4705", toBase: -1000),
        ]

        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: txs,
            vendors: [payVendor], rules: [paymentRule, defaultRule], accounts: [payroll]
        )

        // The -1000 payment is dropped entirely; only the $100 charge remains in the default bucket.
        #expect(result.count == 1)
        #expect(result[0].amount == 100)
    }

    @Test("refunds net against charges within their bucket (signed)")
    func computeRefundNets() {
        let defaultRule = TransferRule(name: "Default", vendor: nil, sourceAccountId: 20, targetAccountId: 1)
        let payroll = makeAccount(id: 20, type: "depository")
        let txs = [
            makeTransaction(id: 1, payee: "Target", toBase: 500),
            makeTransaction(id: 2, payee: "Target", toBase: -500), // mistaken charge refunded same period
        ]
        let result = TransferBreakdown.compute(
            accountId: 1,
            periodTransactions: txs,
            vendors: [], rules: [defaultRule], accounts: [payroll]
        )
        #expect(result.count == 1)
        #expect(result[0].amount == 0) // net zero — no overpay
    }
}

// MARK: - WeeklyPaydownReport (charge-allocation end-to-end)
//
// Models Bill's setup on PNC Core: Cloud 9 → Reserve, everything else → Payroll, and a
// payment rule excluding "THANK YOU FOR YOUR PMT". The amount to pay is purely the period's
// charges per source — a card payment posting can never inflate it.

@Suite struct WeeklyPaydownReportTests {
    private let coreId = 344066
    private let reserveId = 344059
    private let payrollId = 344060

    @Test("per-source buckets exclude payments and net refunds")
    func perSourceAllocation() {
        let core = Account(lunchMoneyId: coreId, name: "Core", displayName: "PNC Core", type: "credit",
                           subtype: "credit card", mask: "4705", institutionName: "PNC", status: "active",
                           balance: "451.10", currency: "usd")
        let reserve = makeAccount(id: reserveId, type: "depository")
        let payroll = makeAccount(id: payrollId, type: "depository")

        let cloud9 = Vendor(name: "Cloud 9", filterText: "cloud 9")
        let payVendor = Vendor(name: "PNC Payment", filterText: "THANK YOU FOR YOUR PMT")
        let rules = [
            TransferRule(name: "Cloud 9 → Reserve", vendor: cloud9, sourceAccountId: reserveId, targetAccountId: coreId, priority: 1),
            TransferRule(name: "Everything Else → Payroll", vendor: nil, sourceAccountId: payrollId, targetAccountId: coreId, priority: 0),
            TransferRule(name: "PNC Payment", vendor: payVendor, targetAccountId: coreId, kind: .payment),
        ]
        // Period 6/13–6/19; includes Cloud 9 charges, other charges, and a big card payment.
        let txs = [
            makeTransaction(id: 1, payee: "Cloud 9 Aviation", toBase: 197.30, date: "2026-06-14", plaidAccountId: coreId),
            makeTransaction(id: 2, payee: "Target", toBase: 240.79, date: "2026-06-15", plaidAccountId: coreId),
            makeTransaction(id: 3, payee: "Walmart", toBase: 60, date: "2026-06-16", plaidAccountId: coreId),
            makeTransaction(id: 4, payee: "THANK YOU FOR YOUR PMT 06/16 XXXX4705", toBase: -962.96, date: "2026-06-16", plaidAccountId: coreId),
        ]

        let reports = WeeklyPaydownReport.compute(
            accounts: [core, reserve, payroll],
            transactions: txs,
            rules: rules,
            vendors: [cloud9, payVendor],
            dateRange: PaydownDateRange(start: "2026-06-13", end: "2026-06-19")
        )

        #expect(reports.count == 1)
        let report = reports[0]
        let reserveBucket = report.buckets.first { $0.sourceAccountName.contains("\(reserveId)") || $0.ruleName.contains("Cloud 9") }
        let payrollBucket = report.buckets.first { $0.ruleName.contains("Everything Else") }
        #expect((reserveBucket?.amount ?? 0).isApprox(197.30))
        #expect((payrollBucket?.amount ?? 0).isApprox(300.79)) // 240.79 + 60, payment excluded
        // Amount to pay is the sum of charge buckets — the −962.96 payment never inflates it.
        #expect((report.amountToPay - 498.09).magnitude < 0.005)

        let body = WeeklyPaydownReport.notificationBody(from: reports)
        #expect(body.contains("PNC Core"))
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
