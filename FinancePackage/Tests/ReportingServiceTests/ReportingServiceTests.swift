import Testing
@testable import ReportingService
import FinanceCoreSDK
import Foundation

// MARK: - Helpers

private extension Double {
    func isApprox(_ other: Double, tol: Double = 0.005) -> Bool { (self - other).magnitude < tol }
}

// MARK: - LWW merge

@Suite struct LWWMergeTests {
    private func rule(_ idSuffix: Int, name: String, updated: TimeInterval, deleted: Bool = false) -> TransactionType {
        TransactionType(
            id: stableId(idSuffix),
            name: name,
            kind: .spend,
            targetAccountId: 1,
            updatedAt: Date(timeIntervalSinceReferenceDate: updated),
            isDeleted: deleted
        )
    }
    private func stableId(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    @Test("union of disjoint ids — absence is not deletion")
    func unionDisjoint() {
        let a = [rule(1, name: "A", updated: 100)]
        let b = [rule(2, name: "B", updated: 100)]
        let merged = lwwMerge(a, b)
        #expect(Set(merged.map { $0.id }) == Set([stableId(1), stableId(2)]))
    }

    @Test("newer updatedAt wins regardless of argument order")
    func newerWins() {
        let older = rule(1, name: "old", updated: 100)
        let newer = rule(1, name: "new", updated: 200)
        #expect(lwwMerge([older], [newer]).first?.name == "new")
        #expect(lwwMerge([newer], [older]).first?.name == "new")
    }

    @Test("a newer tombstone propagates the deletion")
    func tombstoneWins() {
        let live = rule(1, name: "live", updated: 100)
        let dead = rule(1, name: "live", updated: 200, deleted: true)
        let merged = lwwMerge([live], [dead])
        #expect(merged.count == 1)
        #expect(merged.first?.isDeleted == true)
    }

    @Test("an older tombstone does not resurrect-block a newer live edit")
    func newerLiveBeatsOlderTombstone() {
        let dead = rule(1, name: "x", updated: 100, deleted: true)
        let revived = rule(1, name: "x", updated: 200, deleted: false)
        #expect(lwwMerge([dead], [revived]).first?.isDeleted == false)
    }

    @Test("equal timestamps: a delete wins the tie deterministically")
    func tieDeletePrefers() {
        let live = rule(1, name: "x", updated: 100, deleted: false)
        let dead = rule(1, name: "x", updated: 100, deleted: true)
        #expect(lwwMerge([live], [dead]).first?.isDeleted == true)
        #expect(lwwMerge([dead], [live]).first?.isDeleted == true)
    }
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

// MARK: - TransactionClassifier

@Suite struct TransactionClassifierTests {
    @Test("matches by payee substring; highest priority wins")
    func classify() {
        let cloud9 = TransactionType(name: "Cloud 9", kind: .spend, targetAccountId: 1, payeePatterns: ["Cloud 9"], priority: 1)
        let pmt = TransactionType(name: "PNC Payment", kind: .payment, targetAccountId: 1, payeePatterns: ["THANK YOU FOR YOUR PMT"], priority: 5)
        let types = [cloud9, pmt]
        #expect(TransactionClassifier.type(for: makeTransaction(payee: "Cloud 9 Aviation"), in: types)?.name == "Cloud 9")
        #expect(TransactionClassifier.isPayment(makeTransaction(payee: "THANK YOU FOR YOUR PMT 06/20"), in: types))
        #expect(TransactionClassifier.type(for: makeTransaction(payee: "Target"), in: types) == nil)
    }

    @Test("tombstoned types never match")
    func ignoresTombstones() {
        let dead = TransactionType(name: "Cloud 9", kind: .spend, targetAccountId: 1, payeePatterns: ["Cloud 9"], isDeleted: true)
        #expect(TransactionClassifier.type(for: makeTransaction(payee: "Cloud 9 Aviation"), in: [dead]) == nil)
    }
}

// MARK: - WeeklyPaydownReport — the three reports
//
// Models Bill's PNC Core: Cloud 9 (spend, funded by Reserve) and PNC Payment (payment, excluded).
// Total Spend sums non-payment txns by type; Payments Owed is balance-based with payments excluded
// from the adjustments; the Cloud 9 funded spend is carved out of owedFromPrimary.

@Suite struct WeeklyPaydownReportTests {
    private let coreId = 344066
    private let reserveId = 344059

    private func setup() -> (account: Account, types: [TransactionType], accounts: [Account]) {
        let core = Account(lunchMoneyId: coreId, name: "Core", displayName: "PNC Core", type: "credit",
                           subtype: "credit card", mask: "4705", institutionName: "PNC", status: "active",
                           balance: "1000.00", currency: "usd")
        let reserve = makeAccount(id: reserveId, type: "depository")
        let types = [
            TransactionType(name: "Cloud 9", kind: .spend, fundingAccountId: reserveId, targetAccountId: coreId, payeePatterns: ["Cloud 9"], priority: 1),
            TransactionType(name: "PNC Payment", kind: .payment, targetAccountId: coreId, payeePatterns: ["THANK YOU FOR YOUR PMT"], priority: 5),
        ]
        return (core, types, [core, reserve])
    }

    @Test("payments excluded from spend and owed; Cloud 9 carved out; refunds net")
    func threeReports() {
        let (_, types, accounts) = setup()
        // Period 6/13–6/19. balance=1000.
        let txs = [
            // in-period charges (posted)
            makeTransaction(id: 1, payee: "Cloud 9 Aviation", toBase: 200, date: "2026-06-14", plaidAccountId: coreId),
            makeTransaction(id: 2, payee: "Target", toBase: 100, date: "2026-06-15", plaidAccountId: coreId),
            makeTransaction(id: 3, payee: "Target", toBase: -40, date: "2026-06-15", plaidAccountId: coreId), // refund nets
            // in-period pending (not in balance)
            makeTransaction(id: 4, payee: "Amazon", isPending: true, toBase: 50, date: "2026-06-16", plaidAccountId: coreId),
            // a card payment in-period — excluded everywhere
            makeTransaction(id: 5, payee: "THANK YOU FOR YOUR PMT 06/16", toBase: -300, date: "2026-06-16", plaidAccountId: coreId),
            // post-period posted charge (in balance, belongs to next week) — subtracted from owed
            makeTransaction(id: 6, payee: "Walmart", toBase: 70, date: "2026-06-22", plaidAccountId: coreId),
            // post-period payment — excluded from owed adjustment
            makeTransaction(id: 7, payee: "THANK YOU FOR YOUR PMT 06/22", toBase: -500, date: "2026-06-22", plaidAccountId: coreId),
        ]

        let report = WeeklyPaydownReport.compute(
            accounts: accounts, transactions: txs, types: types,
            dateRange: PaydownDateRange(start: "2026-06-13", end: "2026-06-19")
        )[0]

        // Total Spend: Cloud 9 (200) + Other (100 − 40 + 50 pending) = 200 + 110. Payments excluded.
        #expect((report.spend.total).isApprox(310))
        let cloud9Bucket = report.spend.buckets.first { $0.typeName == "Cloud 9" }
        let otherBucket = report.spend.buckets.first { $0.typeName == "Other Spend" }
        #expect((cloud9Bucket?.amount ?? 0).isApprox(200))
        #expect((otherBucket?.amount ?? 0).isApprox(110))

        // Total Payments: 300 (in-period payment only).
        #expect((report.payments.total).isApprox(300))
        #expect(report.payments.count == 1)

        // Payments Owed: balance 1000 + pending(50) − postedAfter(70, payment excluded) = 980.
        #expect((report.owed.pendingInPeriod).isApprox(50))
        #expect((report.owed.postedAfterPeriod).isApprox(70))
        #expect((report.owed.owedTotal).isApprox(980))
        // Cloud 9 (200) carved out to Reserve; owedFromPrimary = 980 − 200 = 780.
        #expect((report.owed.fundedByAccount.first?.amount ?? 0).isApprox(200))
        #expect((report.owed.owedFromPrimary).isApprox(780))

        let body = WeeklyPaydownReport.notificationBody(from: [report])
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
